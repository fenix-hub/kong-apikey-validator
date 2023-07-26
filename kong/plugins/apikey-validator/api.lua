local json = require "lunajson"

local consumer_schema = kong.db.consumers.schema;


return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self, db)
        kong.log("GET /apikey/generate")
        kong.log(db)
        kong.log(json.encode(consumer_schema))
        return kong.response.exit(200, { message = "GET /apikey/generate" })
      end,
    },
  },
}
