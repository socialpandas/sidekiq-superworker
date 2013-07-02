module Sidekiq
  module Superworker
    class Logging
      class Pretty < Logger::Formatter
        def call(severity, time, program_name, message)
          "#{Time.now.utc.iso8601} Superworker #{severity}: #{message}\n"
        end
      end

      def self.initialize_logger(log_target = STDOUT)
        @logger = Logger.new(log_target)
        @logger.level = Logger::INFO
        @logger.formatter = Pretty.new
        @logger
      end

      def self.logger
        @logger || initialize_logger
      end

      def self.logger=(log)
        @logger = (log ? log : Logger.new('/dev/null'))
      end

      def logger
        Sidekiq::Superworker::Logging.logger
      end
    end
  end
end
