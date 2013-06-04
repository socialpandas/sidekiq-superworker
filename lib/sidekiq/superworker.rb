require 'sidekiq'

directory = File.dirname(File.absolute_path(__FILE__))
Dir.glob("#{directory}/superworker/**/*.rb") { |file| require file }
Dir.glob("#{directory}/../generators/sidekiq/superworker/**/*.rb") { |file| require file }
Dir.glob("#{directory}/../../app/models/sidekiq/superworker/*.rb") { |file| require file }

module Sidekiq
  module Superworker
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
