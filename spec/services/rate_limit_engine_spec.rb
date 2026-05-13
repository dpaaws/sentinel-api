# spec/services/rate_limit_engine_spec.rb
require 'fakeredis'
require 'connection_pool'
require_relative '../../app/services/rate_limit_engine'

RSpec.describe Sentinel::RateLimitEngine do
  # Swap the real Redis pool for a FakeRedis-backed pool in tests.
  # No actual Redis process needed. Tests run offline, fast.
  before(:all) do
    Object.send(:remove_const, :REDIS_POOL) if defined?(REDIS_POOL)
    Object.send(:remove_const, :LUA_SCRIPT_SHA) if defined?(LUA_SCRIPT_SHA)
    Object.send(:remove_const, :LUA_SCRIPT) if defined?(LUA_SCRIPT)

    Object.const_set(:REDIS_POOL, ConnectionPool.new(size: 1, timeout: 1) { Redis.new })
    lua_path = File.join(__dir__, '../../lib/lua/sliding_window.lua')
    Object.const_set(:LUA_SCRIPT, File.read(lua_path))
    Object.const_set(:LUA_SCRIPT_SHA,
                     REDIS_POOL.with { |r| r.script(:load, LUA_SCRIPT) })
  end

  let(:engine) { described_class.new(limit: 3, window: 60) }
  let(:api_key) { 'test-key' }

  describe '#check' do
    context 'when under the limit' do
      it 'allows the request and returns correct remaining count' do
        result = engine.check(api_key: api_key, path: '/api/test')
        expect(result.allowed?).to be true
        expect(result.remaining).to eq(2)  # 3 limit - 1 used
      end

      it 'decrements remaining on each call' do
        engine.check(api_key: api_key, path: '/api/test2')
        engine.check(api_key: api_key, path: '/api/test2')
        result = engine.check(api_key: api_key, path: '/api/test2')
        expect(result.allowed?).to be true
        expect(result.remaining).to eq(0)
      end
    end

    context 'when limit is exceeded' do
      before do
        3.times { engine.check(api_key: api_key, path: '/api/burst') }
      end

      it 'blocks the request' do
        result = engine.check(api_key: api_key, path: '/api/burst')
        expect(result.allowed?).to be false
      end

      it 'returns a positive retry_after value' do
        result = engine.check(api_key: api_key, path: '/api/burst')
        expect(result.retry_after).to be > 0
      end

      it 'returns zero remaining' do
        result = engine.check(api_key: api_key, path: '/api/burst')
        expect(result.remaining).to eq(0)
      end
    end

    context 'key namespacing' do
      it 'scopes limits independently per path' do
        3.times { engine.check(api_key: api_key, path: '/api/a') }
        result = engine.check(api_key: api_key, path: '/api/b')
        expect(result.allowed?).to be true
      end

      it 'scopes limits independently per api_key' do
        3.times { engine.check(api_key: 'key-x', path: '/shared') }
        result = engine.check(api_key: 'key-y', path: '/shared')
        expect(result.allowed?).to be true
      end
    end
  end
end
