# Sentinel-API — Project Structure

sentinel-api/
├── app/
│   ├── api/
│   │   └── v1/
│   │       └── proxy.rb          # Route handler: forward ke upstream service
│   ├── middleware/
│   │   ├── api_key_authenticator.rb  # Rack middleware: validasi API key
│   │   ├── rate_limit_enforcer.rb    # Rack middleware: enforce rate limit
│   │   └── structured_logger.rb     # Rack middleware: async structured logging
│   └── services/
│       └── rate_limiter/
│           ├── base.rb              # Abstract interface
│           ├── sliding_window.rb    # Sliding Window Log implementation
│           └── token_bucket.rb      # Token Bucket implementation
├── config/
│   ├── application.rb           # Sinatra app class, middleware stack mounting
│   ├── initializers/
│   │   ├── redis.rb             # Connection pool setup
│   │   └── logging.rb           # SemanticLogger config
│   └── lua/
│       ├── sliding_window.lua   # Lua script untuk atomic Redis ops
│       └── token_bucket.lua
├── lib/
│   └── sentinel/
│       └── graceful_shutdown.rb # Signal trapping & drain logic
├── spec/
│   ├── spec_helper.rb
│   ├── middleware/
│   │   ├── api_key_authenticator_spec.rb
│   │   └── rate_limit_enforcer_spec.rb
│   └── services/
│       └── rate_limiter/
│           └── sliding_window_spec.rb
├── .env.example
├── config.ru                    # Rack entrypoint
├── Gemfile
└── README.md
