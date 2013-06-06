module Sidekiq
  module Superworker
    class SubjobProcessor
      def self.enqueue(subjob)
        # Only enqueue subjobs that aren't running, complete, etc
        return unless subjob.status == 'initialized'
        
        # If this is a parallel subjob, enqueue all of its children
        if subjob.subworker_class == 'parallel'
          subjob.update_attribute(:status, 'running')
          jids = subjob.children.collect do |child|
            enqueue(child)
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
        subjob.update_attribute(:status, 'complete')

        # If children are present, enqueue the first one
        children = subjob.children
        if children.present?
          enqueue(children.first)
          return
        # Otherwise, set this as having its descendants complete
        else
          descendants_are_complete(subjob)
        end
      end

      def self.descendants_are_complete(subjob)
        subjob.update_attribute(:descendants_are_complete, true)

        parent = subjob.parent
        is_child_of_parallel = parent && parent.subworker_class == 'parallel'

        # If this is a child of a parallel subjob, check to see if the parent's descendants are all complete
        # and call descendants_are_complete(parent) if so
        if parent
          siblings_descendants_are_complete = parent.children.all? { |child| child.descendants_are_complete }
          if siblings_descendants_are_complete
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

          # Otherwise, if a parent exists, the parent's descendants are complete
          if parent
            descendants_are_complete(parent)
          # Otherwise, this is the final subjob of the superjob
          else
            SuperjobProcessor.complete(subjob.superjob_id)
          end
        end
      end
    end
  end
end
