-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")

---------------------------------------------------------------------------------------------
-- In the code below, just remove the opening brackets; `[[` to enable a specific handler
--
-- The handlers are based on the OpenResty handlers, see the OpenResty docs for details
-- on when exactly they are invoked and what limitations each handler has.
---------------------------------------------------------------------------------------------

local http = require "resty.http"
local json = require "lunajson"

local plugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}



-- do initialization here, any module level code runs in the 'init_by_lua_block',
-- before worker processes are forked. So anything you add here will run once,
-- but be available in all workers.



-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function plugin:init_worker()

  -- your custom code here
  kong.log.debug("saying hi from the 'init_worker' handler")

end --]]



--[[ runs in the 'ssl_certificate_by_lua_block'
-- IMPORTANT: during the `certificate` phase neither `route`, `service`, nor `consumer`
-- will have been identified, hence this handler will only be executed if the plugin is
-- configured as a global plugin!
function plugin:certificate(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'certificate' handler")

end --]]



--[[ runs in the 'rewrite_by_lua_block'
-- IMPORTANT: during the `rewrite` phase neither `route`, `service`, nor `consumer`
-- will have been identified, hence this handler will only be executed if the plugin is
-- configured as a global plugin!
function plugin:rewrite(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'rewrite' handler")

end --]]



-- runs in the 'access_by_lua_block'
function plugin:access(conf)

  -- your custom code here
  kong.log.inspect(conf)   -- check the logs for a pretty-printed config!
  --kong.service.request.set_header(conf.request_header, "this is on a request")

  -- make sure the request headers contains an APIKey in the X-API-Key header
  local apikey = kong.request.get_header(conf.request_header)
  if not apikey then
    kong.response.exit(401, { message = "No API key found in request" })
  end

  -- [validation phase]
  -- make an http request to the key manager service to validate the APIKey
  -- the apikey is in the form {PREFIX}.{TOKEN}, extract the PREFIX and TOKEN
  local prefix, payload = apikey:match("([^.]*)%.(.*)")

  local httpc = http.new()
  httpc:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  local body = { prefix = prefix, payload = payload }

  kong.log("Making request " .. conf.method .. " " .. conf.url .. conf.path .. " with body " .. json.encode(body))

  local response, err = httpc:request_uri(conf.url, {
    method = "POST",
    path = conf.path,
    body = json.encode(body),
    headers = {
      ["User-Agent"] = "apikey-validator/1.0", -- .. version,
      ["Content-Type"] = "application/json",
      ["X-Forwarded-Host"] = kong.request.get_host(),
      ["X-Forwarded-Path"] = kong.request.get_path(),
      ["X-Forwarded-Query"] = kong.request.get_query(),
    }
  })

  kong.log("Response: " .. response.body .. " " .. response.status)

  -- the key might be expired, revoked, etc.
  -- if the key manager service returns a 401, then the APIKey is invalid
  if response.status == 401 then
    kong.response.exit(401, { message = "Invalid API key" })
  end

  -- if the key manager service returns a 500, then something went wrong
  if response.status == 500 then
    kong.response.exit(500, { message = "Internal server error" })
  end

  -- if the key manager service returns a 200, then the APIKey is valid
  if response.status >= 200 and response.status < 300 then
    kong.log("APIKey is valid")
  end

  -- [rate limiting phase]
  -- make an http request to the rate limiter service to get the counters for the APIKey
  --local body = { prefix = prefix }
  --local response, err = httpc:request_uri("http://localhost:8000/rate-limiter", {
  --  method = "POST",
  --  path = "/rate-limiter",
  --  body = json.encode(body),
  --  headers = {
  --    ["User-Agent"] = "apikey-validator/1.0", -- .. version,
  --    ["Content-Type"] = "application/json",
  --    ["X-Forwarded-Host"] = kong.request.get_host(),
  --    ["X-Forwarded-Path"] = kong.request.get_path(),
  --    ["X-Forwarded-Query"] = kong.request.get_query(),
  --  }
  --})
  --
  ---- the response body contains a list of counters for the APIKey, one for each rate limit, e.g.: [{ id, name, max_value, current_value }]
  ---- for each counter, check if the current_value is greater than the max_value
  ---- if so, then the rate limit has been exceeded, and the request should be rejected
  --local counters = json.decode(response.body)
  --for _, counter in ipairs(counters) do
  --  if counter.current_value >= counter.max_value then
  --    kong.response.exit(429, { message = "Rate limit exceeded" })
  --    kong.log("Rate limit exceeded: " .. counter.name .. " (" .. counter.current_value .. "/" .. counter.max_value .. ")")
  --  end
  --end

  -- if conf.forward_path then
  --   body["path"] = kong.request.get_path()
  -- end

  -- if conf.forward_query then
  --   body["query"] = kong.request.get_query()
  -- end

  -- if conf.forward_headers then
  --   body["headers"] = kong.request.get_headers()
  -- end

  -- if conf.forward_body then
  --   body["body"] = kong.request.get_body()
  -- endl

  --local version = 1.0
  --
  --local response, err = httpc:request_uri("http://localhost:8001", {
  --  method = "GET",
  --  path = "/services",
  --  body = json.encode(body),
  --  headers = {
  --    ["User-Agent"] = "the-middleman/" .. version,
  --    ["Content-Type"] = "application/json",
  --    ["X-Forwarded-Host"] = kong.request.get_host(),
  --    ["X-Forwarded-Path"] = kong.request.get_path(),
  --    ["X-Forwarded-Query"] = kong.request.get_query(),
  --  }
  --})

  if err then
    kong.log("Error: " .. err)
  end

  if response then
    kong.log("Response: " .. response.body)
  end


end --]]


-- runs in the 'header_filter_by_lua_block'
function plugin:header_filter(conf)

  -- your custom code here, for example;
  kong.response.set_header(conf.response_header, "this is on the response")

end --]]


--[[ runs in the 'body_filter_by_lua_block'
function plugin:body_filter(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'body_filter' handler")

end --]]


--[[ runs in the 'log_by_lua_block'
function plugin:log(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'log' handler")

end --]]


-- return our plugin object
return plugin
