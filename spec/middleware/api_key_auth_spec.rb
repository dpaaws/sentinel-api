# spec/middleware/api_key_auth_spec.rb
#
# Rack::Test lets us exercise the full middleware stack without booting
# a real server. Requests are in-process — tests finish in milliseconds.

require 'rack/test'
require 'oj'
require_relative '../../app/middleware/api_key_auth'
require_relative '../../config/initializers/logger'

RSpec.describe Sentinel::ApiKeyAuth do
  include Rack::Test::Methods

  # Stub upstream app — just returns 200 OK
  let(:inner_app) do
    lambda { |_env| [200, { 'Content-Type' => 'application/json' }, ['{"ok":true}']] }
  end

  let(:app) { described_class.new(inner_app) }

  def response_body
    Oj.load(last_response.body, mode: :compat)
  end

  describe 'valid API key' do
    it 'passes request through to the inner app' do
      get '/api/v1/status', {}, { 'HTTP_X_API_KEY' => 'test-key-123' }
      expect(last_response.status).to eq(200)
    end

    it 'sets sentinel.api_key in env' do
      captured_env = nil
      spy_app = lambda do |env|
        captured_env = env
        [200, {}, ['']]
      end
      described_class.new(spy_app).call(
        Rack::MockRequest.env_for('/api/v1/status', 'HTTP_X_API_KEY' => 'test-key-123')
      )
      expect(captured_env['sentinel.api_key']).to eq('test-key-123')
    end
  end

  describe 'missing API key' do
    it 'returns 401' do
      get '/api/v1/status'
      expect(last_response.status).to eq(401)
    end

    it 'returns UNAUTHORIZED error code' do
      get '/api/v1/status'
      expect(response_body.dig('error', 'code')).to eq('UNAUTHORIZED')
    end
  end

  describe 'invalid API key' do
    it 'returns 401 for an unknown key' do
      get '/api/v1/status', {}, { 'HTTP_X_API_KEY' => 'hacker-key' }
      expect(last_response.status).to eq(401)
    end
  end

  describe 'bypass paths' do
    it 'allows /health without any key' do
      get '/health'
      expect(last_response.status).to eq(200)
    end

    it 'allows /metrics without any key' do
      get '/metrics'
      expect(last_response.status).to eq(200)
    end
  end
end
