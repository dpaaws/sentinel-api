# app/middleware/api_key_auth.rb
#
# Runs BEFORE routing. Invalid requests never reach Sinatra.
# In production: load valid keys from Redis/DB at boot and cache with TTL.

require_relative '../../config/initializers/logger'
require 'oj'

module Sentinel
  class ApiKeyAuth
    VALID_KEYS   = ENV.fetch('API_KEYS', 'test-key-123,demo-key-456')
                       .split(',').map(&:freeze).freeze
    BYPASS_PATHS = %w[/health /metrics].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      return @app.call(env) if BYPASS_PATHS.include?(request.path)

      api_key = env['HTTP_X_API_KEY']

      unless api_key && VALID_KEYS.include?(api_key)
        LOGGER.warn('auth_failed',
          path: request.path, method: request.request_method, ip: request.ip)
        body = Oj.dump({ error: { code: 'UNAUTHORIZED',
                                  message: 'Valid X-API-Key header required' } },
                       mode: :compat)
        return [401, { 'Content-Type' => 'application/json',
                       'Content-Length' => body.bytesize.to_s }, [body]]
      end

      env['sentinel.api_key'] = api_key
      @app.call(env)
    end
  end
end
