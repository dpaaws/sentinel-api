-- config/lua/sliding_window.lua
--
-- KENAPA Lua di Redis?
-- Rate limiting butuh READ-then-WRITE yang atomic. Kalau kita lakuin ini
-- dari Ruby (GET count -> check -> INCR), ada window di antara dua operasi
-- itu. Di high concurrency, dua request bisa baca count yang sama sebelum
-- salah satunya nge-INCR — ini race condition klasik yang bikin rate limit
-- bisa di-bypass.
--
-- Redis Lua scripts dieksekusi atomically — Redis single-threaded, script
-- jalan tanpa interupsi. Ini solusi paling clean tanpa butuh distributed lock.
--
-- ARGV[1] = window_size (detik), ARGV[2] = max_requests, ARGV[3] = now (epoch ms)
-- KEYS[1] = rate_limit key (biasanya "rl:{api_key}:{window_bucket}")

local key        = KEYS[1]
local window     = tonumber(ARGV[1]) * 1000  -- convert ke milliseconds
local limit      = tonumber(ARGV[2])
local now        = tonumber(ARGV[3])
local window_start = now - window

-- Hapus semua entry di luar window sliding (expired)
redis.call("ZREMRANGEBYSCORE", key, "-inf", window_start)

-- Hitung berapa request yang masih dalam window
local count = redis.call("ZCARD", key)

if count >= limit then
  -- Over limit — kembaliin info buat header response
  local oldest = redis.call("ZRANGE", key, 0, 0, "WITHSCORES")
  local reset_at = oldest[2] and (tonumber(oldest[2]) + window) or (now + window)
  return { 0, count, reset_at }
end

-- Add request ini ke sorted set, score = timestamp
redis.call("ZADD", key, now, now .. "-" .. math.random(1000000))
-- Set TTL supaya key otomatis cleanup kalau nggak ada traffic
redis.call("PEXPIRE", key, window)

return { 1, count + 1, now + window }
