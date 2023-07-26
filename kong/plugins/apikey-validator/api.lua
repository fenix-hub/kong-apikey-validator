
local consumer_schema = kong.db.consumers.schema;

return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        kong.log("GET /apikey/generate")
        kong.log(consumer_schema.table)
        return kong.response.exit(200, { message = "GET /apikey/generate" })
      end,
    },
  },
}
