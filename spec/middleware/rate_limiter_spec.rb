# spec/middleware/rate_limiter_spec.rb

require 'rack/test'
require 'fakeredis'
require 'connection_pool'
require 'oj'
require_relative '../../app/middleware/rate_limiter'
require_relative '../../config/initializers/logger'

RSpec.describe Sentinel::RateLimiter do
  include Rack::Test::Methods

  before(:all) do
    # Wire up in-memory Redis for tests
    Object.send(:remove_const, :REDIS_POOL)    if defined?(REDIS_POOL)
    Object.send(:remove_const, :LUA_SCRIPT_SHA) if defined?(LUA_SCRIPT_SHA)
    Object.send(:remove_const, :LUA_SCRIPT)     if defined?(LUA_SCRIPT)

    Object.const_set(:REDIS_POOL, ConnectionPool.new(size: 1, timeout: 1) { Redis.new })
    lua_path = File.join(__dir__, '../../lib/lua/sliding_window.lua')
    Object.const_set(:LUA_SCRIPT, File.read(lua_path))
    Object.const_set(:LUA_SCRIPT_SHA, REDIS_POOL.with { |r| r.script(:load, LUA_SCRIPT) })
  end

  # Stub inner app
  let(:inner_app) { lambda { |_env| [200, { 'Content-Type' => 'application/json' }, ['ok']] } }
  let(:app)       { described_class.new(inner_app) }

  def env_with_key(path = '/api/test', key = 'my-key')
    Rack::MockRequest.env_for(path).merge('sentinel.api_key' => key)
  end

  describe 'rate limit headers on allowed requests' do
    it 'adds X-RateLimit headers to response' do
      status, headers, = app.call(env_with_key)
      expect(headers.keys).to include('X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Window')
    end

    it 'decrements X-RateLimit-Remaining on repeated calls' do
      first_remaining  = app.call(env_with_key)[1]['X-RateLimit-Remaining'].to_i
      second_remaining = app.call(env_with_key)[1]['X-RateLimit-Remaining'].to_i
      expect(second_remaining).to eq(first_remaining - 1)
    end
  end

  describe 'when limit is exceeded' do
    let(:stingy_engine) { Sentinel::RateLimitEngine.new(limit: 2, window: 60) }

    before do
      # Exhaust limit for this specific key
      2.times { app.call(env_with_key('/api/burst', 'burst-key')) }
    end

    it 'returns 429' do
      status, = app.call(env_with_key('/api/burst', 'burst-key'))
      expect(status).to eq(429)
    end

    it 'includes Retry-After header' do
      _, headers, = app.call(env_with_key('/api/burst', 'burst-key'))
      expect(headers['Retry-After'].to_i).to be > 0
    end

    it 'returns RATE_LIMITED error code in body' do
      _, _, body = app.call(env_with_key('/api/burst', 'burst-key'))
      parsed = Oj.load(body.join, mode: :compat)
      expect(parsed.dig('error', 'code')).to eq('RATE_LIMITED')
    end
  end

  describe 'when no api_key in env' do
    it 'passes through without rate checking (auth middleware handles this)' do
      env = Rack::MockRequest.env_for('/health')  # no sentinel.api_key
      status, = app.call(env)
      expect(status).to eq(200)
    end
  end
end
