local json = require "lunajson"

local consumer_schema = {
  name          = "consumers",
  primary_key   = { "id" },
  endpoint_key  = "username",
  workspaceable = true
}


return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        kong.log(consumer_schema.name)
        return kong.response.exit(200, { body = json.encode(consumer_schema.name) })
      end,
    },
  },
}
