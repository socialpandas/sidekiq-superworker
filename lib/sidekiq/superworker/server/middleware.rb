module Sidekiq
  module Superworker
    module Server
      class Middleware
        def initialize(options=nil)
          @processor = Sidekiq::Superworker::Processor.new
        end

        def call(worker, item, queue)
          yield
          @processor.complete(item)
        end
      end
    end
  end
end
