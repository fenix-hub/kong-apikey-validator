local endpoints = require "kong.api.endpoints"

local credentials_schema = kong.db.keyauth_credentials.schema

return {
  ["/consumers/:consumers/key-auth/"] = {
    schema = credentials_schema,
    methods = {
      GET = endpoints.get_collection_endpoint(
              credentials_schema, kong.db.keyauth_credentials),
    },
  },
}
