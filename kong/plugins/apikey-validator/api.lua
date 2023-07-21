return {
  ["/apikey-validator"] = {
    methods = {
      resource = "apikey-validator",
      GET = function(self)
        local request = self.req
        kong.log("request: " .. request)
        return kong.response.exit(200, { message = "Rate limit exceeded" })
        --local apikeys, err = db.apikeys:find_all()
        --if err then
        --  return helpers.yield_error(err)
        --end
        --return helpers.responses.send_HTTP_OK(apikeys)
      end,
    },
  },
}
