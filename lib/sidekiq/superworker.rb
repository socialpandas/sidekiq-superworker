require 'sidekiq'

directory = File.dirname(File.absolute_path(__FILE__))
Dir.glob("#{directory}/superworker/**/*.rb") { |file| require file }
Dir.glob("#{directory}/../generators/sidekiq/superworker/**/*.rb") { |file| require file }
Dir.glob("#{directory}/../../app/models/sidekiq/superworker/*.rb") { |file| require file }

module Sidekiq
  module Superworker
    def self.logger
      Logging.logger
    end

    def self.debug(message)
      logger.debug(message)
    end

    def self.table_name_prefix
      'sidekiq_superworker_'
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

  # Make Cleaner ignore superjobs, as they don't exist in Redis and thus won't be synced with Sidekiq::Monitor::Job
  Sidekiq::Monitor::Cleaner.add_ignored_queue(Sidekiq::Superworker::SuperjobProcessor.queue_name) if defined?(Sidekiq::Monitor)

  # Add a custom view that shows the subjobs for a superjob
  custom_views_directory = "#{directory}/../../app/views/sidekiq/superworker/subjobs"
  Sidekiq::Monitor::CustomViews.add 'Subjobs', custom_views_directory do |job|
    job.queue == Sidekiq::Superworker::SuperjobProcessor.queue_name.to_s
  end

end
