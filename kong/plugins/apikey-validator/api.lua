local json = require "lunajson"

local consumer_schema = {
  name          = "consumers",
  primary_key   = { "id" },
  endpoint_key  = "username",
  workspaceable = true,

  fields        = {
    {
      username = {
        description =
        "The unique username of the Consumer. You must send either this field or custom_id with the request.",
        type = "string",
        unique = true
      },
    },
    {
      custom_id =
      {
        description = "Stores the existing unique ID of the consumer.",
        type = "string",
        unique = true
      },
    },
  },

  entity_checks = {
    { at_least_one_of = { "custom_id", "username" } },
  },
}


return {
  ["/apikey/generate"] = {
    schema = consumer_schema,
    methods = {
      GET = function(self)
        kong.log(consumer_schema.name)
        return kong.response.exit(200, { body = json.encode(consumer_schema.fields) })
      end,
    },
  },
}
