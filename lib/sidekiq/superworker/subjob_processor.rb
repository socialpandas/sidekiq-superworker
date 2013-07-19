module Sidekiq
  module Superworker
    class SubjobProcessor
      def self.enqueue(subjob)
        Superworker.debug "#{subjob.to_info}: Trying to enqueue"
        # Only enqueue subjobs that aren't running, complete, etc
        return unless subjob.status == 'initialized'
        
        Superworker.debug "#{subjob.to_info}: Enqueueing"
        # If this is a parallel subjob, enqueue all of its children
        if subjob.subworker_class == 'parallel'
          subjob.update_attribute(:status, 'running')

          Superworker.debug "#{subjob.to_info}: Enqueueing parallel children"
          jids = subjob.children.collect do |child|
            enqueue(child)
          end
          jid = jids.first
        elsif subjob.subworker_class == 'batch'
          subjob.update_attribute(:status, 'running')

          Superworker.debug "#{subjob.to_info}: Enqueueing batch children"
          jids = subjob.children.collect do |child|
            child.update_attribute(:status, 'running')
            enqueue(child.children.first)
          end
          jid = jids.first
        else
          klass = "::#{subjob.subworker_class}".constantize

          # If this is a superworker, mark it as complete, which will queue its children or its next subjob
          if klass.respond_to?(:is_a_superworker?) && klass.is_a_superworker?
            complete(subjob)
          # Otherwise, enqueue it in Sidekiq
          else
            jid = enqueue_in_sidekiq(subjob, klass)
            subjob.update_attributes(
              jid: jid,
              status: 'queued'
            )
          end
        end
        jid
      end

      def self.enqueue_in_sidekiq(subjob, klass)
        Superworker.debug "#{subjob.to_info}: Enqueueing in Sidekiq"

        # If sidekiq-unique-jobs is being used for this worker, a number of issues arise if the subjob isn't
        # queued, so we'll bypass the unique functionality of the worker while running the subjob.
        is_unique = klass.respond_to?(:sidekiq_options_hash) && !!klass.sidekiq_options_hash['unique']
        if is_unique
          unique_value = klass.sidekiq_options_hash.delete('unique')
          unique_job_expiration_value = klass.sidekiq_options_hash.delete('unique_job_expiration')
        end

        arg_values = subjob.arg_values
        jid = klass.perform_async(*arg_values)
        warn "Nil JID returned by #{subjob.subworker_class}.perform_async with arguments #{arg_values}" if jid.nil?

        if is_unique
          klass.sidekiq_options_hash['unique'] = unique_value
          klass.sidekiq_options_hash['unique_job_expiration'] = unique_job_expiration_value
        end

        jid
      end

      def self.complete(subjob)
        Superworker.debug "#{subjob.to_info}: Complete"
        subjob.update_attribute(:status, 'complete')

        # If children are present, enqueue the first one
        children = subjob.children
        if children.present?
          Superworker.debug "#{subjob.to_info}: Enqueueing children"
          enqueue(children.first)
          return
        # Otherwise, set this as having its descendants complete
        else
          descendants_are_complete(subjob)
        end
      end

      def self.error(subjob, worker, item, exception)
        Superworker.debug "#{subjob.to_info}: Error"
        subjob.update_attribute(:status, 'failed')
        SuperjobProcessor.error(subjob.superjob_id, worker, item, exception)
      end

      def self.descendants_are_complete(subjob)
        Superworker.debug "#{subjob.to_info}: Descendants are complete"
        subjob.update_attribute(:descendants_are_complete, true)

        if subjob.subworker_class == 'batch_child' || subjob.subworker_class == 'batch'
          complete(subjob)
        end

        parent = subjob.parent
        is_child_of_parallel = parent && parent.subworker_class == 'parallel'

        # If a parent exists, check whether this subjob's siblings are all complete
        if parent
          siblings_descendants_are_complete = parent.children.all? { |child| child.descendants_are_complete }
          if siblings_descendants_are_complete
            Superworker.debug "#{subjob.to_info}: Parent (#{parent.to_info}) is complete"
            descendants_are_complete(parent)
            parent.update_attribute(:status, 'complete') if is_child_of_parallel
          end
        end

        unless is_child_of_parallel
          # If a next subjob is present, enqueue it
          next_subjob = subjob.next
          if next_subjob
            enqueue(next_subjob)
            return
          end

          # If there isn't a parent, then, this is the final subjob of the superjob
          unless parent
            Superworker.debug "#{subjob.to_info}: Superjob is complete"
            SuperjobProcessor.complete(subjob.superjob_id)
          end
        end
      end
    end
  end
end
