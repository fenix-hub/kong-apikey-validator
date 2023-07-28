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
  VERSION = "0.4.0", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

local vconf = {}

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

  vconf = conf

  -- make sure the request headers contains an APIKey in the X-API-Key header
  local apikey = kong.request.get_header(conf.request_header)
  if not apikey then
    return kong.response.error(401, { message = "No API key found in request" })
  end

  -- [validation phase]
  local httpc = http.new()
  httpc:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  local body = { apiKey = apikey, serviceId = "SERVICE_ID_HERE" }

  local headers = {
    ["User-Agent"] = "apikey-validator/" .. ApikeyValidator.VERSION,
    ["Content-Type"] = "application/json",
    ["X-Saatisfied-Forwarded-Host"] = kong.request.get_host(),
    ["X-Saatisfied-Forwarded-Path"] = kong.request.get_path(),
    ["X-Saatisfied-Forwarded-Query"] = kong.request.get_query(),
  }

  kong.log.debug("Making request " .. conf.method .. " " .. conf.url .. conf.path)
  local response, err = httpc:request_uri(conf.url, {
    method = conf.method,
    path = conf.path,
    body = json.encode(body),
    headers = headers,
  })

  if err then
    kong.log.err("Error: " .. err)
    return kong.response.error(500, { message = "Internal server error" }, headers)
  end

  local prefix, _ = apikey:match("([^.]*)%.(.*)")
  apikey = nil

  kong.log.debug("Response: " .. response.body .. " " .. response.status)

  -- the key might be expired, revoked, etc.
  -- if the key manager service returns a 401, then the APIKey is invalid
  if response.status == 401 then
    return kong.response.error(401, { message = "API Key expired or revoked" }, headers)
  end

  if response.status == 400 then
    return kong.response.error(400, { message = "API Key not valid" }, headers)
  end

  -- if the key manager service returns a 500, then something went wrong
  if response.status == 500 or err then
    return kong.response.error(500, { message = "Internal server error" }, headers)
  end

  -- if the key manager service returns a 200, then the APIKey is valid
  if response.status >= 200 and response.status < 300 then
    kong.log.info("APIKey is valid")
    kong.response.set_header("X-Saatisfied-User", "user")
    kong.response.set_header("X-Saatisfied-Service", "service")
    kong.response.set_header("X-Saatisfied-PaymentConfiguration", "paymentconf")
  end

  -- [rate limiting phase]

  -- connect to redis
  local redis_client = redis.connect(conf.redis_host, conf.redis_port)
  if redis_client:ping() ~= true then
    kong.log.err("Could not connect to redis")
    return kong.response.error(500, { message = "Internal server error" }, headers)
  end

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
      return kong.response.error(429, { message = "Rate limit exceeded" })
    -- else apply the rate limiting logic
    else
      switch(rate_limiting_logics):case(limit.p, limit, redis_client)
    end
  end

  :: continue ::
end --]]


-- runs in the 'header_filter_by_lua_block'
function ApikeyValidator:header_filter(conf)

  -- your custom code here, for example;
  kong.response.set_header(conf.response_header, "this is on the response")

end --]]

function ApikeyValidator.get_vconf()
  return vconf
end


--[[ runs in the 'body_filter_by_lua_block'
function ApikeyValidator:body_filter(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'body_filter' handler")

end --]]


--[[ runs in the 'log_by_lua_block'
function ApikeyValidator:log(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'log' handler")

end --]]


-- return our ApikeyValidator object
return ApikeyValidator
