-- workaround
local EmptySchema = {}
function EmptySchema:new()
  local self = {}
  function self.each_field(...) return function() end end
  return self
end

return {
  ["/apikey-validator/generate"] = {
    methods = {
      schema = nil,
      GET = function(self)
        local request = self.req
        kong.log("request: " .. request)
        return kong.response.exit(200, { message = "Rate limit exceeded" })
      end,
    },
  },
}
