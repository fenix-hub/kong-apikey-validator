local function increment_limit(client, idx, amount)
  local res = client:hincrby(idx, "c", amount);
end

-- handle different types of rate limiting logics based on the limit parameter
--it can be CALL, MONTHS, CHARACTERS, using a switch statement based on a table
local rate_limiting_logics = {
  ["CALL"] = function(limit, client)
    increment_limit(client, limit.idx, 1)
  end,
  ["MONTHS"] = function(limit, client)
    -- do something else
  end,
  ["CHARACTERS"] = function(limit, client)
    -- do something else
  end,
  default = function(limit, client)
    increment_limit(client, limit.idx, limit.i)
  end,
}

return rate_limiting_logics
