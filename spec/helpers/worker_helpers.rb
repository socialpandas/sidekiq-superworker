module Sidekiq
  module Superworker
    module WorkerHelpers
      def dummy_worker_queue
        'sidekiq_superworker_test'
      end

      def create_dummy_workers
        # Create dummy Sidekiq worker classes: Worker1..Worker9
        queue_name = dummy_worker_queue
        (1..9).each do |i|
          class_name = "Worker#{i}"
          next if Object.const_defined?(class_name)
          klass = Class.new do
            include Sidekiq::Worker

            sidekiq_options :queue => queue_name

            def perform
              nil
            end
          end

          Object.const_set(class_name, klass)
        end
      end

      def clean_datastores
        DatabaseCleaner.clean_with(:truncation)
        @queue.clear
      end

      def trigger_completion_of_sidekiq_job(subjob_id)
        subjob = Sidekiq::Superworker::Subjob.where(subjob_id: subjob_id).first
        raise "Subjob not found: subjob_id: #{subjob_id}" unless subjob
        raise "Blank JID for subjob: subjob_id: #{subjob_id}" if subjob.jid.blank?
        job = find_sidekiq_job_by_jid(subjob.jid)
        raise "Subjob not found: subjob_id: JID: #{jid}" unless job
        Sidekiq::Superworker::Processor.new.complete(job.item, false)
        job.delete
      end

      def find_sidekiq_job_by_jid(jid)
        @queue.each do |job|
          return job if job.jid == jid
        end
        nil
      end

      def subjobs_to_indexed_hash(subjobs)
        attributes = [
          :subjob_id,
          :parent_id,
          :children_ids,
          :next_id,
          :subworker_class,
          :superworker_class,
          :arg_keys,
          :arg_values,
          :status,
          :descendants_are_complete
        ]

        hash_array = subjobs.collect do |subjob|
          attributes.inject({}) { |hash, attribute| hash[attribute] = subjob.send(attribute); hash }
        end
        add_indexes_to_subjobs_hash_array(hash_array)
      end

      def add_indexes_to_subjobs_hash_array(subjobs_array)
        subjobs_array.inject({}) { |hash, record_hash| hash[record_hash[:subjob_id]] = record_hash; hash }
      end

      def subjob_statuses_should_equal(hash)
        expected_statuses = {}
        hash.each do |ids, status|
          ids = [ids] unless ids.is_a?(Enumerable)
          ids.each { |id| expected_statuses[id] = status}
        end
        actual_statuses = Hash[Sidekiq::Superworker::Subjob.order(:subjob_id).collect { |subjob| [subjob.subjob_id, subjob.status] }]
        actual_statuses.should == expected_statuses
      end
    end
  end
end