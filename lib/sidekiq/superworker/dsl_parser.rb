module Sidekiq
  module Superworker
    class DSLParser
      def self.parse(block)
        @dsl_evaluator = DSLEvaluator.new
        @dsl_hash = DSLHash.new
        @record_id = 0
        block_to_nested_hash(block)
      end

      def self.block_to_nested_hash(block)
        fiber = Fiber.new do
          @dsl_evaluator.instance_eval(&block)
        end
        
        nested_hash = {}
        while (method_result = fiber.resume)
          method, args, block = method_result
          @record_id += 1
          if block
            if method == :batch
              nested_hash[@record_id] = { subworker_class: method, arg_keys: args, children: block_to_nested_hash(block) }
            else
              nested_hash[@record_id] = { subworker_class: method, arg_keys: args, children: block_to_nested_hash(block) }
            end
          else
            nested_hash[@record_id] = { subworker_class: method, arg_keys: args }
          end

          # For superworkers nested within other superworkers, we'll take the subworkers' nested_hash,
          # adjust their ids to fit in with our current @record_id value, and add them into the tree.
          unless [:parallel, :batch].include?(method)
            subworker_class = method.to_s.constantize
            if subworker_class.respond_to?(:is_a_superworker?) && subworker_class.is_a_superworker?
              parent_record_id = @record_id
              nested_hash[parent_record_id][:children] = @dsl_hash.rewrite_ids_of_nested_hash(subworker_class.nested_hash, @record_id)
              @record_id = @dsl_hash.record_id
            end
          end
        end
        nested_hash
      end
    end
  end
end
