-- daos.lua
local typedefs = require "kong.db.schema.typedefs"


return {
  -- this plugin only results in one custom DAO, named `apikey`:
  {
    name                  = "apikeyrequest", -- the actual table in the database
    primary_key           = { "id" },
    generate_admin_api    = false,
    fields = {
      {
        -- a value to be inserted by the DAO itself
        -- (think of serial id and the uniqueness of such required here)
        serviceId = typedefs.uuid,
      },
      {
        -- a foreign key to a consumer's id
        purchaseId = {
          type      = "number",
        },
      },
    },
  },
}
