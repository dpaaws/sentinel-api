# app/services/rate_limit_engine.rb
#
# Pure service object. No HTTP, no Rack.
# The Lua script runs atomically in Redis — one round trip, zero race conditions.

require_relative '../../config/initializers/redis'

module Sentinel
  class RateLimitEngine
    Result = Struct.new(:allowed?, :remaining, :retry_after, keyword_init: true)

    def initialize(limit: 100, window: 60)
      @limit  = limit
      @window = window * 1_000  # seconds -> ms for Redis sorted sets
    end

    def check(api_key:, path: '*')
      key = "sentinel:rl:#{api_key}:#{path}"
      now = (Time.now.to_f * 1000).to_i

      raw = REDIS_POOL.with do |redis|
        redis.evalsha(LUA_SCRIPT_SHA, keys: [key], argv: [now, @window, @limit])
      rescue Redis::CommandError => e
        # Redis flushed script cache (e.g. restart). Reload and retry once.
        raise unless e.message.include?('NOSCRIPT')
        sha = redis.script(:load, LUA_SCRIPT)
        redis.evalsha(sha, keys: [key], argv: [now, @window, @limit])
      end

      allowed = raw[0] == 1
      Result.new(
        allowed?:    allowed,
        remaining:   allowed ? raw[1].to_i : 0,
        retry_after: allowed ? nil : raw[1].to_i
      )
    end
  end
end
