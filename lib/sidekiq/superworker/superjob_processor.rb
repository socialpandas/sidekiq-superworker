module Sidekiq
  module Superworker
    class SuperjobProcessor
      def self.queue_name
        :superworker
      end

      def self.create(superjob_id, superworker_class_name, args, subjobs)
        # If sidekiq_monitor is being used, create a Sidekiq::Monitor::Job for the superjob
        if defined?(Sidekiq::Monitor)
          now = Time.now
          Sidekiq::Monitor::Job.create(
            jid: superjob_id,
            queue: queue_name,
            class_name: superworker_class_name,
            args: args,
            enqueued_at: now,
            started_at: now,
            status: 'running'
          )
        end

        # Enqueue the first root-level subjob
        first_subjob = subjobs.select{ |subjob| subjob.parent_id.nil? }.first
        SubjobProcessor.enqueue(first_subjob)
      end

      def self.complete(superjob_id)
        # Set the superjob Sidekiq::Monitor::Job as being complete
        if defined?(Sidekiq::Monitor)
          job = Sidekiq::Monitor::Job.where(queue: queue_name, jid: superjob_id).first
          if job
            job.update_attributes(
              status: 'complete',
              finished_at: Time.now
            )
          end
        end
      end

      def self.error(superjob_id, worker, item, exception)
        if defined?(Sidekiq::Monitor)
          job = Sidekiq::Monitor::Job.where(queue: queue_name, jid: superjob_id).first
          if job
            result = {
              message: "#{exception.message} (thrown in #{worker.class}, JID: #{item['jid']})",
              backtrace: exception.backtrace
            }
            job.update_attributes(
              finished_at: DateTime.now,
              status: 'failed',
              result: result
            )
          end
        end
      end
    end
  end
end
