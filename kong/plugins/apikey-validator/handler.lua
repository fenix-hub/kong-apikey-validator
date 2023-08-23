-- If you're not sure your ApikeyValidator is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the ApikeyValidator is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")

---------------------------------------------------------------------------------------------
-- In the code below, just remove the opening brackets; `[[` to enable a specific handler
--
-- The handlers are based on the OpenResty handlers, see the OpenResty docs for details
-- on when exactly they are invoked and what limitations each handler has.
---------------------------------------------------------------------------------------------

-- TODO: user https://github.com/Kong/kong/blob/master/kong/plugins/key-auth/handler.lua as a reference

local http = require "resty.http"
local json = require "lunajson"

local ApikeyValidator = {
  PRIORITY = 1000, -- set the ApikeyValidator priority, which determines ApikeyValidator execution order
  VERSION = "0.5.1", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

-- do initialization here, any module level code runs in the 'init_by_lua_block',
-- before worker processes are forked. So anything you add here will run once,
-- but be available in all workers.

-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function ApikeyValidator:init_worker()

  -- your custom code here
  kong.log.debug("saying hi from the 'init_worker' handler")

end --]]

--[[ runs in the 'ssl_certificate_by_lua_block'
-- IMPORTANT: during the `certificate` phase neither `route`, `service`, nor `consumer`
-- will have been identified, hence this handler will only be executed if the ApikeyValidator is
-- configured as a global ApikeyValidator!
function ApikeyValidator:certificate(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'certificate' handler")

end --]]



--[[ runs in the 'rewrite_by_lua_block'
-- IMPORTANT: during the `rewrite` phase neither `route`, `service`, nor `consumer`
-- will have been identified, hence this handler will only be executed if the ApikeyValidator is
-- configured as a global ApikeyValidator!
function ApikeyValidator:rewrite(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'rewrite' handler")

end --]]

-- TODO: set response headers based on kong.service... and kong.constants

-- runs in the 'access_by_lua_block'
function ApikeyValidator:access(conf)

  for j, ignore_tag in pairs(ngx.ctx.service.tags) do
    if ignore_tag == "saatisfied_unauthorized" then
      return
    end
  end

  httpc = http.new()
  httpc:set_timeouts(5000, 10000, 10000)


  local service_id = kong.router.get_service().id
  -- kong.log(ngx.ctx.service.tags)
  -- kong.log(ngx.ctx.service.id)

  -- make sure the request headers contains an APIKey in the X-API-Key header
  local apikey = kong.request.get_header(conf.request_header)
  if not apikey then
    return kong.response.error(401, "No API key found in request")
  end

  -- [validation phase]

  local body = { apiKey = apikey, serviceId = service_id }

  kong.log("Making APIKey verification request " .. conf.validation_method .. " " .. conf.validation_url .. conf.validation_path )
  local response, err = httpc:request_uri(conf.validation_url, {
    method = conf.validation_method,
    path = conf.validation_path,
    body = json.encode(body),
    headers = {
      ["User-Agent"] = "apikey-validator/" .. ApikeyValidator.VERSION,
      ["Content-Type"] = "application/json",
    },
  })

  if err then
    kong.log.err("Error: " .. err)
    return kong.response.error(500, "Internal server error", headers)
  end

  kong.log("Response: " .. response.body .. " " .. response.status)

  local prefix, _ = apikey:match("([^.]*)%.(.*)")
  apikey = nil


  -- the key might be expired, revoked, etc.
  -- if the key manager service returns a 401, then the APIKey is invalid
  if response.status == 400 then
    return kong.response.error(400, "API Key not valid", headers)
  end

  if response.status == 401 then
    return kong.response.error(401, "API Key expired or revoked", headers)
  end

  if response.status == 403 then
    return kong.response.error(403, "API Key not authorized", headers)
  end

  -- if the key manager service returns a 500, then something went wrong
  if response.status >= 500 or err then
    return kong.response.error(500, "Internal server error", headers)
  end

  -- if the key manager service returns a 200, then the APIKey is valid
  if response.status >= 200 and response.status < 300 then
    kong.log.info("APIKey is valid")
  end


  -- getting APIKey info
  kong.log("Making APIKey info request.. " .. conf.info_method .. " " .. conf.info_url .. conf.info_path .. "/" .. prefix )
  local response, err = httpc:request_uri(conf.info_url, {
    method = conf.info_method,
    path = conf.info_path .. "/" .. prefix,
    headers = headers,
  })

  kong.log(response.body)

  if err then
    kong.log.err("Error: " .. err)
    return kong.response.error(500, "Internal server error", headers)
  end

  if response.status == 404 then
    return kong.response.error(404, "API Key not found", headers)
  end

  if response.status == 500 or err then
    return kong.response.error(500, "Internal server error", headers)
  end

  if response.status >= 200 and response.status < 300 then
    kong.log.info("APIKey info received")
  end

  -- decode the response body and set request headers
  local apikey_info = json.decode(response.body)

  local saatistied_augmentation_headers = {
    ["X-Saatisfied-User"] = apikey_info["owner"],
    ["X-Saatisfied-Service"] = apikey_info["product"],
    ["X-Saatisfied-Payment-Configuration"] = apikey_info["contract"],
  }

  for k, v in pairs(saatistied_augmentation_headers) do
    kong.service.request.set_header(k, v)
  end



  ---------- [rate limiting phase] ------------

  kong.log("Making Check limits request.." .. conf.check_method .. " " .. conf.ratelimiter_url .. conf.check_path .. "/" .. prefix )
  local response, err = httpc:request_uri(conf.ratelimiter_url, {
    method = conf.check_method,
    path = conf.check_path .. "/" .. prefix,
    headers = headers,
  })

  if err then
    kong.log.err("Error: " .. err)
    return kong.response.error(500, "Internal server error", headers)
  end

  if response.status == 404 then
    return kong.response.error(404, "API Key not found", headers)
  end

  if response.status == 429 then
    return kong.response.exit(response.status, response.body)
  end

  if response.status == 500 or err then
    return kong.response.error(500, "Internal server error", headers)
  end

  if response.status >= 200 and response.status < 300 then
    kong.log.info("APIKey info received")
  end

  :: continue ::
end --]]

function ApikeyValidator:get_vconf()
  return vconf
end


function ApikeyValidator:response(conf)
  -- [[ update counters ]]
  kong.log.debug("Making Count request.." )

  httpc = http.new()
  httpc:set_timeouts(5000, 10000, 10000)

  local response, err = httpc:request_uri(conf.ratelimiter_url, {
    method = conf.count_method,
    path = conf.count_path .. "/" .. prefix,
    headers = {
      ["User-Agent"] = "apikey-validator/" .. ApikeyValidator.VERSION,
      ["Content-Type"] = "application/json",
    },
  })

  if err or response.status == 500 then
    kong.log.err("Error: " .. err)
  end

end

-- return our ApikeyValidator object
return ApikeyValidator
