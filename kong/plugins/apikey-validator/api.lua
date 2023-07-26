
local consumer_schema = kong.db.consumers.schema;
local json = require "lunajson"

return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self, db)
        kong.log("GET /apikey/generate")
        kong.log(db)
        kong.log(json.decode(consumer_schema))
        return kong.response.exit(200, { message = "GET /apikey/generate" })
      end,
    },
  },
}
