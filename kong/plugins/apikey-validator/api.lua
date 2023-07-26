
local credentials_schema = kong.db.consumers.schema;

return {
  ["/apikey/generate"] = {
    schema = credentials_schema,
    methods = {
      GET = function(self)
        kong.log("GET /apikey/generate")
        kong.log(credentials_schema)
        return kong.response.exit(200, { message = "GET /apikey/generate" })
      end,
    },
  },
}
