return {
  ["/apikey-validator"] = {
    methods = {
      GET = function(self)
        local request = self.req
        kong.log("request: " .. request)
        return kong.response.exit(200, { message = "Rate limit exceeded" })
      end,
    },
  },
}
