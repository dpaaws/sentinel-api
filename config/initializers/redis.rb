# config/initializers/redis.rb
#
# ConnectionPool keeps N independent connections pre-warmed.
# Threads check out a connection, use it, return it — zero blocking.
# Pool size rule of thumb: match Puma thread count.

require 'redis'
require 'connection_pool'

REDIS_POOL = ConnectionPool.new(
  size:    Integer(ENV.fetch('REDIS_POOL_SIZE', 10)),
  timeout: Float(ENV.fetch('REDIS_POOL_TIMEOUT', 1.5))
) do
  Redis.new(
    url:                ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    connect_timeout:    0.5,
    read_timeout:       0.5,
    write_timeout:      0.5,
    reconnect_attempts: 2
  )
end

# Pre-load Lua script at boot so EVALSHA has zero compilation overhead per request
LUA_SCRIPT     = File.read(File.join(__dir__, '../../lib/lua/sliding_window.lua'))
LUA_SCRIPT_SHA = REDIS_POOL.with { |r| r.script(:load, LUA_SCRIPT) }.freeze
