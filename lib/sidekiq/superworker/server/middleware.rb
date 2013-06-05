module Sidekiq
  module Superworker
    module Server
      class Middleware
        def initialize(options=nil)
          @processor = Sidekiq::Superworker::Processor.new
        end

        def call(worker, item, queue)
          begin
            yield
          rescue Exception => exception
            @processor.error(worker, item, queue, exception)
            raise exception
          end
          @processor.complete(item)
        end
      end
    end
  end
end
