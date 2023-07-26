return {
  ["/apikey/generate"] = {
    methods = {
      GET = function()
        return kong.response.exit(200)
      end,
    },
  },
}
