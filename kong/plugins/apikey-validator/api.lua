local consumer_schema = kong.db.apikey-validator.schema;


return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        kong.log(consumer_schema.fields)
        kong.log(consumer_schema.name)
        return kong.response.exit(200, consumer_schema)
      end,
    },
  },
}
