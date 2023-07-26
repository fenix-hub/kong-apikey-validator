local json = require "lunajson"

local consumer_schema = kong.db.consumers.schema;


return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        kong.log(consumer.custom_id)
        return kong.response.exit(200, consumer_schema)
      end,
    },
  },
}
