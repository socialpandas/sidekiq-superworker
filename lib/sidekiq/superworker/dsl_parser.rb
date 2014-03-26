module Sidekiq
  module Superworker
    class DSLParser
      MODULE_SEPARATOR = '__'

      def parse(block)
        @dsl_evaluator = DSLEvaluator.new
        @record_id = 0
        nested_hash = block_to_nested_hash(block)
        DSLHash.new(nested_hash).rewrite_record_ids(1)
      end

      def block_to_nested_hash(block)
        fiber = Fiber.new do
          @dsl_evaluator.instance_eval(&block)
        end
        
        nested_hash = {}
        while (method_result = fiber.resume)
          add_method_result_to_nested_hash(nested_hash, method_result)
        end
        nested_hash
      end

      def add_method_result_to_nested_hash(nested_hash, method_result)
        method, args, block = method_result
        subworker_type = method_to_subworker_type(method)
        @record_id += 1
        method_record_id = @record_id

        record = { subworker_class: subworker_type, arg_keys: args }
        record[:children] = block_to_nested_hash(block) if block
        nested_hash[method_record_id] = record

        # For superworkers nested within other superworkers, we'll take the subworkers' nested_hash,
        # adjust their ids to fit in with our current @record_id value, and add them into the tree.
        unless [:parallel, :batch].include?(subworker_type)
          subworker_class = subworker_type.to_s.constantize
          if subworker_class.respond_to?(:is_a_superworker?) && subworker_class.is_a_superworker?
            dsl_hash = DSLHash.new(subworker_class.nested_hash)
            children = dsl_hash.rewrite_record_ids(@record_id + 1)
            set_children_for_record_id(nested_hash, method_record_id, children)
            @record_id = dsl_hash.record_id
          end
        end
      end

      def set_children_for_record_id(nested_hash, parent_record_id, children)
        nested_hash.each do |record_id, value|
          if record_id == parent_record_id
            if nested_hash[record_id][:children].present?
              nested_hash[record_id][:children] = nested_hash[record_id][:children].reverse_merge(children)
            else
              nested_hash[record_id][:children] = children
            end
          end
          if value[:children].present?
            set_children_for_record_id(value[:children], parent_record_id, children)
          end
        end
      end

      def method_to_subworker_type(method)
        method = method.to_s
        if method.include?(MODULE_SEPARATOR)
          method_pieces = method.split(MODULE_SEPARATOR)
          class_name = method_pieces.pop
          module_name = method_pieces.join('::')
        else
          module_name = nil
          class_name = method
        end

        return class_name.to_sym if module_name.nil?

        begin
          namespaced_class = [module_name, class_name].compact.join('::').constantize
        rescue NameError
          namespaced_class = [module_name, class_name].compact.join(MODULE_SEPARATOR).constantize
        end
        namespaced_class.to_s
      end
    end
  end
end
