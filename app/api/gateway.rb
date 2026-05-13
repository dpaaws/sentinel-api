# app/api/gateway.rb
# Sinatra routes — intentionally thin. All cross-cutting concerns live in middleware.

require 'sinatra/base'
require 'oj'
require_relative '../../config/initializers/logger'

module Sentinel
  class Gateway < Sinatra::Base
    set :show_exceptions, false

    get '/health' do
      content_type :json
      Oj.dump({ status: 'ok', ts: Time.now.utc.iso8601 }, mode: :compat)
    end

    get '/api/v1/status' do
      content_type :json
      Oj.dump({
        message:            'Sentinel is watching.',
        api_key:            env['sentinel.api_key'],
        remaining_requests: env['sentinel.rl_remaining']
      }, mode: :compat)
    end

    not_found do
      content_type :json
      status 404
      Oj.dump({ error: { code: 'NOT_FOUND', message: 'Route not found' } }, mode: :compat)
    end

    error do
      content_type :json
      LOGGER.error('unhandled_exception', error: env['sinatra.error']&.message)
      status 500
      Oj.dump({ error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' } }, mode: :compat)
    end
  end
end
