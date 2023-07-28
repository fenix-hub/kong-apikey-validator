local http = require "resty.http"
local json = require "lunajson"
local redis = require "redis"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"

local conf = require "kong.plugins.apikey-validator.schema"

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
          ["X-Saatisfied-Forwarded-Host"] = kong.request.get_host(),
          ["X-Saatisfied-Forwarded-Path"] = kong.request.get_path(),
          ["X-Saatisfied-Forwarded-Query"] = kong.request.get_query(),
        }

        local body = { serviceId = kong.req.params_post.serviceId, purchaseId = kong.req.params_post.purchaseId }

        kong.log("Making request " .. conf.method .. " " .. conf.url .. conf.path .. " " .. json.encode(body))
        local response, err = httpc:request_uri(conf.url, {
          method = conf.method,
          path = "/apikey/generate",
          body = json.encode(body),
          headers = headers,
        })

        return kong.response.exit(200, { message = "OK" })
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
