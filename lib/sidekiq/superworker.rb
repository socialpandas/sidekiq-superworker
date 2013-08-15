require 'sidekiq'

directory = File.dirname(File.absolute_path(__FILE__))
require "#{directory}/client_ext.rb"
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

  # Add a "superjob:{id}" search filter
  Sidekiq::Monitor::JobsDatatable.add_search_filter({
    pattern: /^superjob:([\d]+)$/,
    filter: lambda do |search_term, records|
      superjob_id = search_term[/^superjob:([\d]+)$/, 1]
      superjob = Sidekiq::Monitor::Job.find_by_id(superjob_id)
      # Return empty set
      return records.where(id: nil) unless superjob
      superjob_jid = superjob.jid
      subjob_jids = Sidekiq::Superworker::Subjob.where(superjob_id: superjob_jid).map(&:jid).compact
      records.where(jid: subjob_jids + [superjob_jid])
    end
  })

end
