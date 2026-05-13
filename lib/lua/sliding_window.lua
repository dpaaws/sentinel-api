-- sliding_window.lua
-- Atomically check + record a request inside a sliding time window.
-- KEYS[1] = rate limit key | ARGV[1] = now (ms) | ARGV[2] = window (ms) | ARGV[3] = limit
-- Returns: {allowed (0|1), remaining_or_retry_after}

local key          = KEYS[1]
local now          = tonumber(ARGV[1])
local window       = tonumber(ARGV[2])
local limit        = tonumber(ARGV[3])
local window_start = now - window

-- Evict stale entries outside the current window
redis.call('ZREMRANGEBYSCORE', key, '-inf', window_start)

local count = redis.call('ZCARD', key)

if count >= limit then
  local oldest      = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
  local retry_after = math.ceil((tonumber(oldest[2]) + window - now) / 1000)
  return {0, retry_after}
end

-- Record request; random suffix handles sub-ms bursts
local member = tostring(now) .. '-' .. tostring(math.random(1, 999999))
redis.call('ZADD', key, now, member)
redis.call('PEXPIRE', key, window)
return {1, limit - count - 1}
