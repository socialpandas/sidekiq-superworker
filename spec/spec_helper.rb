require 'sidekiq-superworker'
require 'rspec/autorun'
require 'support/superworkers'
require 'support/worker_helpers'

require 'sidekiq/api'

Sidekiq::Superworker.options[:delete_subjobs_after_superjob_completes] = false

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.before :all do
    Sidekiq.redis do |conn| conn.flushdb end
  end
end
