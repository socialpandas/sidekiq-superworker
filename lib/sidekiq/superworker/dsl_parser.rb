module Sidekiq
  module Superworker
    class DSLParser
      def self.parse(block)
        @dsl_evaluator = DSLEvaluator.new
        set_records_from_block(block)
        {
          records: @records,
          nested_records: @nested_records
        }
      end

      def self.set_records_from_block(block)
        @record_id = 0
        @records = {}
        @nested_records = block_to_nested_records(block)
        set_records_from_nested_records(@nested_records)
      end

      def self.set_records_from_nested_records(nested_records, parent_id=nil)
        last_id = nil
        nested_records.each do |id, value|
          @records[id] = {
            subjob_id: id,
            subworker_class: value[:subworker_class].to_s,
            arg_keys: value[:arg_keys],
            parent_id: parent_id,
            children_ids: value[:children] ? value[:children].keys : nil
          }
          @records[last_id][:next_id] = id if @records[last_id]
          last_id = id
          set_records_from_nested_records(value[:children], id) if value[:children]
        end
      end

      def self.block_to_nested_records(block)
        fiber = Fiber.new do
          @dsl_evaluator.instance_eval(&block)
        end
        
        nested_records = {}
        while (method_result = fiber.resume)
          method, arg_keys, block = method_result
          @record_id += 1
          if block
            nested_records[@record_id] = { subworker_class: method, arg_keys: arg_keys, children: block_to_nested_records(block) }
          else
            nested_records[@record_id] = { subworker_class: method, arg_keys: arg_keys }
          end

          # For superworkers nested within other superworkers, we'll take the subworkers' nested_records,
          # adjust their ids to fit in with our current @record_id value, and add them into the tree.
          if method != :parallel
            subworker_class = method.to_s.constantize
            if subworker_class.respond_to?(:is_a_superworker?) && subworker_class.is_a_superworker?
              parent_record_id = @record_id
              nested_records[parent_record_id][:children] = rewrite_ids_of_subworker_records(subworker_class.nested_records)
            end
          end
        end
        nested_records
      end

      def self.rewrite_ids_of_subworker_records(nested_records)
        new_hash = {}
        nested_records.each do |old_record_id, record|
          @record_id += 1
          parent_record_id = @record_id
          new_hash[parent_record_id] = record
          if record[:children]
            new_hash[parent_record_id][:children] = rewrite_ids_of_subworker_records(record[:children])
          end
        end
        new_hash
      end
    end
  end
end
