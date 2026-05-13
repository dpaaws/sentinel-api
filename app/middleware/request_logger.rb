# app/middleware/request_logger.rb
#
# Process.clock_gettime(CLOCK_MONOTONIC) is the right clock for duration math —
# immune to NTP jumps and DST changes that can make Time.now go backward.

require_relative '../../config/initializers/logger'

module Sentinel
  class RequestLogger
    def initialize(app)
      @app = app
    end

    def call(env)
      t0      = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      request = Rack::Request.new(env)

      status, headers, body = @app.call(env)

      LOGGER.info('request',
        method:      request.request_method,
        path:        request.path,
        status:      status,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(2),
        ip:          request.ip,
        api_key:     env['sentinel.api_key'],
        remaining:   env['sentinel.rl_remaining']
      )

      [status, headers, body]
    end
  end
end
