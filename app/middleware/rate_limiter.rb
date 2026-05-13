# app/middleware/rate_limiter.rb
#
# Calls RateLimitEngine (pure service), then adds standard RFC headers.
# 429 response includes Retry-After so clients can back off intelligently.

require_relative '../services/rate_limit_engine'
require_relative '../../config/initializers/logger'
require 'oj'

module Sentinel
  class RateLimiter
    RATE_LIMIT  = Integer(ENV.fetch('RATE_LIMIT', 100))
    RATE_WINDOW = Integer(ENV.fetch('RATE_WINDOW_SECS', 60))

    def initialize(app)
      @app    = app
      @engine = RateLimitEngine.new(limit: RATE_LIMIT, window: RATE_WINDOW)
    end

    def call(env)
      api_key = env['sentinel.api_key']
      return @app.call(env) unless api_key

      request = Rack::Request.new(env)
      result  = @engine.check(api_key: api_key, path: request.path)
      env['sentinel.rl_remaining'] = result.remaining

      unless result.allowed?
        LOGGER.warn('rate_limited',
          api_key: api_key, path: request.path, retry_after: result.retry_after)
        body = Oj.dump({ error: { code: 'RATE_LIMITED',
                                  message: 'Too many requests.',
                                  retry_after: result.retry_after } }, mode: :compat)
        return [429, { 'Content-Type' => 'application/json',
                       'Retry-After'  => result.retry_after.to_s }, [body]]
      end

      status, headers, body = @app.call(env)
      headers['X-RateLimit-Limit']     = RATE_LIMIT.to_s
      headers['X-RateLimit-Remaining'] = result.remaining.to_s
      headers['X-RateLimit-Window']    = RATE_WINDOW.to_s
      [status, headers, body]
    end
  end
end
