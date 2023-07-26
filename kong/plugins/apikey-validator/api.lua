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
      GET = function()
        return kong.response.exit(200, { message = "Hello World!" })
      end,
    },
  },
}
