local json = require "lunajson"

local consumer_schema = kong.db.consumers.schema;


return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        kong.log(consumer_schema.fields.custom_id)
        kong.log(json.encode(consumer_schema.fields))
        kong.log(consumer_schema.name)
        return kong.response.exit(200, { body = json.encode(consumer_schema.fields) })
      end,
    },
  },
}
