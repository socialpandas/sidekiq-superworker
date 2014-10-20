require 'sidekiq'

directory = File.dirname(File.absolute_path(__FILE__))
require "#{directory}/client_ext.rb"
Dir.glob("#{directory}/superworker/*.rb") { |file| require file }
Dir.glob("#{directory}/superworker/server/*.rb") { |file| require file }

module Sidekiq
  module Superworker
    DEFAULTS = {
      delete_subjobs_after_superjob_completes: true,
      subjob_redis_prefix: 'subjob'
    }

    def self.options
      @options ||= DEFAULTS.dup
    end

    def self.options=(opts)
      @options = opts
    end

    def self.logger
      Logging.logger
    end

    def self.debug(message)
      logger.debug(message)
    end

  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Superworker::Server::Middleware
  end
end

Superworker = Sidekiq::Superworker::Worker unless Object.const_defined?('Superworker')

if defined?(Sidekiq::Monitor)
  require "#{directory}/superworker/integrations/sidekiq_monitor"
end
