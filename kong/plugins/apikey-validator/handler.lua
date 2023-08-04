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
local redis = require "redis"

local switch = require "kong.plugins.apikey-validator.switch"
local rate_limiting_logics = require "kong.plugins.apikey-validator.rate-limiting"

local ApikeyValidator = {
  PRIORITY = 1000, -- set the ApikeyValidator priority, which determines ApikeyValidator execution order
  VERSION = "0.4.4", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

local _redis_client = nil

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

  local service_id = kong.router.get_service().id
  kong.log(ngx.ctx.service.tags)
  kong.log(ngx.ctx.service.id)
  kong.log(service_id)

  -- make sure the request headers contains an APIKey in the X-API-Key header
  local apikey = kong.request.get_header(conf.request_header)
  if not apikey then
    return kong.response.error(401, "No API key found in request")
  end

  -- [validation phase]
  local httpc = http.new()
  httpc:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  local body = { apiKey = apikey, serviceId = service_id }

  kong.log.debug("Making APIKey verification request " .. conf.method .. " " .. conf.url)
  local response, err = httpc:request_uri(conf.url, {
    method = conf.method,
    path = conf.verification_path,
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

  kong.log.debug("Response: " .. response.body .. " " .. response.status)

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
  kong.log.debug("Making APIKey info request.." )
  local response, err = httpc:request_uri(conf.url, {
    method = "GET",
    path = conf.info_path .. "/" .. prefix,
    headers = headers,
  })

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

  -- connect to redis
  local redis_client = get_redis_client(conf.redis_host, conf.redis_port)

  if redis_client:ping() ~= true then
    kong.log.err("Could not connect to redis")
    return kong.response.error(500, "Internal server error")
  end
  _redis_client = redis_client

  local namespace = conf.redis_apikey_namespace;
  local limits_index = namespace .. prefix;

  -- call redis cache
  local limits_amount = redis_client:get(limits_index .. ":limits");
  kong.log.debug("limits_amount: " .. limits_amount)

  local limits = {};
  for i = 0, limits_amount-1 do
    limits[i+1] = redis_client:hgetall(limits_index .. ":" .. i);
    limits[i+1]["idx"] = limits_index .. ":" .. i;
  end;

  -- check if the current_value is greater than the max_value
  -- if so, then the rate limit has been exceeded, and the request should be rejected
  for i, limit in ipairs(limits) do
    kong.log.info("limit: " .. i .. " " .. json.encode(limit))
    if tonumber(limit.c) >= tonumber(limit.m) then
      kong.log.info("Rate limit exceeded: " .. limit.p .. " (" .. limit.c .. "/" .. limit.m .. ")")
      -- build some headers related to the rate limiting
      return kong.response.error(429, "Rate limit exceeded")
    end
  end

  kong.ctx.plugin[prefix] = limits

  :: continue ::
end --]]

local function get_vconf()
  return nil
end

local function get_redis_client(host, port)
  local redis_client = nil
  if _redis_client ~= nil then
    redis_client = _redis_client
  else
    redis_client = redis.connect(host, port)
  end
  return redis_client
end

function ApikeyValidator:response(conf)
  local redis_client = get_redis_client(conf.redis_host, conf.redis_port)

  -- [apply rate limiting logics]
  for limit in kong.ctx.plugin[prefix] do
    switch(rate_limiting_logics):case(limit.p, limit, redis_client)
  end
end

-- return our ApikeyValidator object
return ApikeyValidator
