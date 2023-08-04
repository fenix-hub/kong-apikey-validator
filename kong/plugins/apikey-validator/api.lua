local http = require "resty.http"
local json = require "lunajson"
local redis = require "redis"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"
local handler = require "kong.plugins.apikey-validator.handler"

-- this is a workaround to avoid the error: 405 Method Not Allowed
local EmptySchema = {}
function EmptySchema:new()
  local self = {}
  function self.each_field(...) return function() end end
  return self
end

-- Schema for /apikey/generate
local GenerateSchema = {
  fields = {
    { serviceId = { type = "string", required = true }, },
    { purchaseId = { type = "string", required = true }, },
  },
}

function GenerateSchema:new()
  local self = {}
  function self.each_field(...) return function() end end
  return self
end

return {
  ["/apikey/generate"] = {
    schema = GenerateSchema:new(),
    methods = {
      POST = function(self)
        local vconf = handler.get_vconf()

        -- get the Authorization header from the request
        local auth_header = self.req.headers["Authorization"]

        -- check if the Authorization header is present
        if auth_header == nil then
          return kong.response.exit(401, { message = "Unauthorized" })
        end

        -- check if it is of type Bearer {TOKEN}
        local _, _, token = string.find(auth_header, "Bearer%s+(.+)")
        if token == nil then
          return kong.response.exit(401, { message = "Unauthorized" })
        end

        -- decode token to get roles claim
        local jwt, err = jwt_decoder:new(token)
        if err then
          -- return false, {status = 401, message = "Bad token; " .. tostring(err)}
          return kong.response.exit(401, { message = "Bad token; " .. tostring(err)})
        end

        -- get the consumer id from the JWT token
        kong.log(jwt.claims.uuid)

        -- set headers
        local headers = {
          ["User-Agent"] = "apikey-validator/" .. "1.0.0",
          ["Content-Type"] = "application/json",
          ["Authorization"] = self.req.headers["Authorization"],
        }

        local body = { userId = jwt.claims.uuid, serviceId = self.args.post.serviceId, purchaseId = self.args.post.purchaseId }

        -- kong.log("Making request " .. vconf.method .. " " .. vconf.url .. " " .. json.encode(body) .. " " .. json.encode(headers))
        local httpc = http.new()
        -- httpc:set_timeouts(vconf.connect_timeout, vconf.send_timeout, vconf.read_timeout)
        local response, err = httpc:request_uri("https://192.168.42.28:8443", {
          method = "POST",
          path = "/api-composer/apikey/generate",
          body = json.encode(body),
          headers = headers,
          ssl_verify = false,
        })

        if err then
          kong.log.err("Error: " .. err)
          return kong.response.exit(500, { message = "Internal server error" }, headers)
        end

        if response.status ~= 200 then
          return kong.response.exit(response.status)
        end

        local response_body = json.decode(response.body)

        -- connect to redis and set the limits
        local redis_client = redis.connect("192.168.42.24", "6378")
        if redis_client:ping() ~= true then
          kong.log.err("Could not connect to redis")
          return kong.response.error(500, { message = "Internal server error" }, headers)
        end

        -- set the limits
        local namespace = "apikey:";
        local prefix, _ = response_body["apiKey"]:match("([^.]*)%.(.*)")
        local limits = response_body["limits"]
        local limits_index = namespace .. prefix;
        for j, limit in ipairs(limits) do
          local i = j - 1
          local hash = limits_index .. ":" .. i
          redis_client:hset(hash, "p", limit["parameter"])
          redis_client:hset(hash, "c", 0)
          redis_client:hset(hash, "m", limit["maxValue"])
          redis_client:hset(hash, "i", limit["incrementBy"])
        end
        kong.log(limits_index .. ":limits", #limits)
        redis_client:set(limits_index .. ":limits", #limits)

        return kong.response.exit(response.status, json.decode(response.body))
      end,
    },
  },
  ["/apikey/validate/:prefix"] = {
    schema = EmptySchema:new(),
    methods = {
      GET = function(self)
        return kong.response.exit(200, { message = "OK" })
      end,
    },
  },
  ["/apikey/validate"] = {
    schema = EmptySchema:new(),
    methods = {
      POST = function(self)
        return kong.response.exit(200, { message = "OK" })
      end,
    },
  },
  ["/apikey/counters/reset"] = {
    schema = EmptySchema:new(),
    methods = {
      POST = function(self)
        return kong.response.exit(200, { message = "OK" })
      end,
    },
  }
}
