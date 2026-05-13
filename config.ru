$LOAD_PATH.unshift(File.join(__dir__))

require 'bundler/setup'
Bundler.require(:default)

require_relative 'config/initializers/redis'
require_relative 'config/initializers/logger'
require_relative 'config/application'

Signal.trap('TERM') do
  LOGGER.info('shutdown', signal: 'TERM', msg: 'Draining Redis pool...')
  REDIS_POOL.shutdown { |conn| conn.close }
  exit(0)
end

Signal.trap('INT') do
  LOGGER.info('shutdown', signal: 'INT')
  REDIS_POOL.shutdown { |conn| conn.close }
  exit(0)
end

run Sentinel.app
