module Sidekiq
  module Superworker
    class Processor
      def complete(item, new_thread=true)
        if new_thread
          # Run this in a new thread so that its execution isn't considered to be part of the
          # completed job's execution.
          Thread.new do
            complete_item(item)
          end
        else
          complete_item(item)
        end
      end

      protected

      def complete_item(item)
        raise "Job has nil jid: #{item}" if item['jid'].nil?
        # The job may complete before the Subjob record is created; in case that happens,
        # we need to sleep briefly and requery.
        tries = 3
        while !(subjob = Subjob.find_by_jid(item['jid'])) && tries > 0
          sleep 1
          tries -= 1
        end
        SubjobProcessor.complete(subjob) if subjob
      end
    end
  end
end
