return {
  ["/apikey/generate"] = {
    schema = {},
    methods = {
      GET = function()
        return kong.response.exit(200, { message = "Hello World!" })
      end,
    },
  },
}
