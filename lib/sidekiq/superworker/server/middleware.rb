module Sidekiq
  module Superworker
    module Server
      class Middleware
        def initialize(options=nil)
          @processor = Sidekiq::Superworker::Processor.new
        end

        def call(worker, item, queue)
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              return_value = yield
            rescue Exception => exception
              @processor.error(worker, item, queue, exception)
              raise exception
            end
            @processor.complete(item)
            return_value
          end
        end
      end
    end
  end
end
