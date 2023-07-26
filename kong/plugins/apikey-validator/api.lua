local consumer_schema = {
  name = "consumer",
  fields = "two"
};

return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        kong.log(consumer_schema.fields)
        kong.log(consumer_schema.name)
        return kong.response.exit(200)
      end,
    },
  },
}
