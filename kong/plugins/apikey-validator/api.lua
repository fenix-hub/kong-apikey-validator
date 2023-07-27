local http = require "resty.http"
local json = require "lunajson"
local redis = require "redis"
-- local jwt = require "luajwt"

local conf = require "kong.plugins.apikey-validator.schema"

-- this is a workaround to avoid the error: 405 Method Not Allowed
local EmptySchema = {}
function EmptySchema:new()
  local self = {}
  function self.each_field(...) return function() end end
  return self
end

return {
  ["/apikey/generate"] = {
    schema = EmptySchema:new(),
    methods = {
      GET = function(self)

        kong.log(kong.ctx.shared.authenticated_jwt_token)

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

        ---- decode the JWT token
        --local decoded, err = jwt.decode(token, nil, false)
        --if err then
        --  return kong.response.exit(401, { message = "Unauthorized" })
        --end
        --
        ---- get the consumer id from the JWT token
        --kong.log(json.decode(decoded))

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
