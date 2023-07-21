local endpoints = require "kong.api.endpoints"
local json = require "lunajson"

return {
  ["/apikeys"] = {
    methods = {
      GET = function(self)
        local request = self.req
        kong.log("request: " .. request)

        --local apikeys, err = db.apikeys:find_all()
        --if err then
        --  return helpers.yield_error(err)
        --end
        --return helpers.responses.send_HTTP_OK(apikeys)
      end,
    },
  },
}
