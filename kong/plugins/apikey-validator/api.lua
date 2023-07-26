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
        kong.log(self)
        return kong.response.exit(200, { message = "OK" })
      end,
    },
  },
}
