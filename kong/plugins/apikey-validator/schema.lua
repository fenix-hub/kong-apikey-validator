local typedefs = require "kong.db.schema.typedefs"


local PLUGIN_NAME = "apikey-validator"


local schema = {
  name = PLUGIN_NAME,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        -- The 'config' record is the custom part of the plugin schema
        type = "record",
        fields = {
          { method = { type = "string", default = "POST", one_of = { "POST", "GET", }, }, },
          { url = typedefs.url({ required = true }) },
          { path = { type = "string" }, },

          -- redis connection properties, including host, port, user and password
          { redis_host = typedefs.host({ required = true }), },
          { redis_port = typedefs.port({ required = true }), },
          { redis_user = { type = "string", len_min = 0 }, },
          { redis_password = { type = "string", len_min = 0 }, },

          { redis_apikey_namespace = { type = "string", default = "apikey:"}, },

          -- timeouts for connecting to the Validator server
          { connect_timeout = { type = "number", default = 5000, }, },
          { send_timeout = { type = "number", default = 10000, }, },
          { read_timeout = {  type = "number", default = 10000, }, },

          -- a standard defined field (typedef), with some customizations
          { request_header = typedefs.header_name {
              required = true,
              default = "Hello-World" } },
          { response_header = typedefs.header_name {
              required = true,
              default = "Bye-World" } },
          { ttl = { -- self defined field
              type = "integer",
              default = 600,
              required = true,
              gt = 0, }}, -- adding a constraint for the value
        },
        entity_checks = {
          -- add some validation rules across fields
          -- the following is silly because it is always true, since they are both required
          { at_least_one_of = { "request_header", "response_header" }, },
          -- We specify that both header-names cannot be the same
          { distinct = { "request_header", "response_header"} },
        },
      },
    },
  },
}

return schema
