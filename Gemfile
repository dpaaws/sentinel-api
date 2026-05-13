source 'https://rubygems.org'
ruby '3.3.0'

# Web framework — Sinatra stays thin; we own the middleware stack
gem 'sinatra',         '~> 4.0'
gem 'puma',            '~> 6.4'       # Multi-threaded app server

# Redis + connection pool — never block on a single connection
gem 'redis',           '~> 5.2'
gem 'connection_pool', '~> 2.4'

# JSON — oj is a C-extension JSON parser, 2-3x faster than stdlib JSON
# Matters when you're serializing thousands of log lines per second
gem 'oj',              '~> 3.16'

# Rack utilities
gem 'rack',            '~> 3.1'

group :development, :test do
  gem 'rspec',         '~> 3.13'
  gem 'rack-test',     '~> 2.1'      # HTTP assertions without booting a server
  gem 'fakeredis',     '~> 0.9'      # In-memory Redis mock for unit tests
  gem 'rubocop',       '~> 1.65', require: false
end
