function bar()
  return {
    name = "consumers",
    fields = "two",
  }
end

consumer_schema = bar()

return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        return kong.response.exit(200)
      end,
    },
  },
}
