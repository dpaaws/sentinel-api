# config/initializers/logger.rb
#
# Every log line is a JSON object — no Grok parsing needed in ELK/Datadog.
# Oj.dump is 2-3x faster than stdlib JSON.generate under load.
# Mutex prevents thread-interleaved partial log lines.

require 'oj'

module Sentinel
  class StructuredLogger
    LEVELS = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4 }.freeze

    def initialize(output: $stdout, level: :info)
      @output    = output
      @min_level = LEVELS.fetch(level)
      @mutex     = Mutex.new
    end

    def log(level, msg, **fields)
      return if LEVELS.fetch(level, 99) < @min_level
      entry = { ts: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'),
                lvl: level.to_s.upcase, msg: msg, pid: Process.pid }.merge(fields)
      line = Oj.dump(entry, mode: :compat)
      @mutex.synchronize { @output.puts(line) }
    end

    %i[debug info warn error fatal].each do |lvl|
      define_method(lvl) { |msg, **fields| log(lvl, msg, **fields) }
    end
  end
end

LOGGER = Sentinel::StructuredLogger.new(level: ENV.fetch('LOG_LEVEL', 'info').to_sym)
