require_relative '../app/middleware/api_key_auth'
require_relative '../app/middleware/rate_limiter'
require_relative '../app/middleware/request_logger'
require_relative '../app/api/gateway'

module Sentinel
  def self.app
    Rack::Builder.new do
      use Sentinel::ApiKeyAuth
      use Sentinel::RateLimiter
      use Sentinel::RequestLogger
      run Sentinel::Gateway
    end
  end
end
