module Sidekiq
  module Superworker
    class DSLHash
      attr_accessor :record_id, :records

      def initialize
        reset
      end

      def nested_hash_to_records(nested_hash, args)
        reset
        @args = args
        nested_hash_to_records_recursive(nested_hash)
      end

      def rewrite_ids_of_nested_hash(nested_hash, record_id)
        reset
        @record_id = record_id
        rewrite_ids_of_nested_hash_recursive(nested_hash)
      end

      private

      def reset
        @args = {}
        @records = {}
        @record_id = 1
      end

      def nested_hash_to_records_recursive(nested_hash, options={})
        return @records if nested_hash.blank?

        defaults = {
          parent_id: nil,
          scoped_args: nil # Args that are scoped to this subset of the nested hash (necessary for batch hashes)
        }
        options.reverse_merge!(defaults)
        parent_id = options[:parent_id]
        last_id = nil

        nested_hash.values.each do |value|
          id = @record_id
          @record_id += 1
          arg_values = value[:arg_keys].collect do |arg_key|
            # Allow for subjob arg_values to be set within the superworker definition; if a symbol is
            # used in the DSL, use @args[arg_key], and otherwise use arg_key as the value
            if arg_key.is_a?(Symbol)
              options[:scoped_args] ? options[:scoped_args][arg_key] : @args[arg_key]
            else
              arg_key
            end
          end
          
          @records[id] = {
            subjob_id: id,
            subworker_class: value[:subworker_class].to_s,
            arg_keys: value[:arg_keys],
            arg_values: arg_values,
            parent_id: parent_id
          }
          if value[:subworker_class] == :batch
            @records[id][:children_ids] = children_ids_for_batch(value[:children], arg_values[0])
          end

          @records[last_id][:next_id] = id if @records[last_id]
          last_id = id

          if parent_id && @records[parent_id]
            @records[parent_id][:children_ids] ||= []
            @records[parent_id][:children_ids] << id
          end

          nested_hash_to_records_recursive(value[:children], parent_id: id, scoped_args: options[:scoped_args]) if value[:children] && value[:subworker_class] != :batch
        end
        @records
      end

      def rewrite_ids_of_nested_hash_recursive(nested_hash)
        new_hash = {}
        nested_hash.each do |old_record_id, record|
          @record_id += 1
          parent_record_id = @record_id
          new_hash[parent_record_id] = record
          if record[:children]
            new_hash[parent_record_id][:children] = rewrite_ids_of_nested_hash_recursive(record[:children])
          end
        end
        new_hash
      end

      def children_ids_for_batch(subjobs, batch_keys_to_iteration_keys)
        iteration_keys = batch_keys_to_iteration_keys.values
        batch_iteration_arg_value_arrays = get_batch_iteration_arg_value_arrays(batch_keys_to_iteration_keys)

        batch_id = @record_id - 1

        children_ids = []
        batch_iteration_arg_value_arrays.each do |batch_iteration_arg_value_array|
          iteration_args = {}
          batch_iteration_arg_value_array.each_with_index do |arg_value, arg_index|
            arg_key = iteration_keys[arg_index]
            iteration_args[arg_key] = arg_value
          end

          batch_child_id = @record_id
          batch_child = {
            subjob_id: batch_child_id,
            subworker_class: 'batch_child',
            arg_keys: iteration_keys,
            arg_values: iteration_args.values,
            parent_id: batch_id
          }
          @records[batch_child_id] = batch_child

          @record_id += 1
          last_subjob_id = nil
          subjobs.values.each_with_index do |subjob, index|
            subjob_id = @record_id
            @record_id += 1
            subjob = subjob.dup
            children = subjob.delete(:children)
            subjob[:subjob_id] = subjob_id
            subjob[:parent_id] = batch_child_id
            subjob[:arg_values] = iteration_args.values
            @records[subjob_id] = subjob
            @records[last_subjob_id][:next_id] = subjob_id if last_subjob_id
            last_subjob_id = subjob_id
            nested_hash_to_records_recursive(children, parent_id: subjob_id, scoped_args: iteration_args)
          end

          children_ids << batch_child_id
        end
        
        children_ids
      end

      # Returns an array of argument value arrays, each of which should be passed to each of the
      # batch iterations
      def get_batch_iteration_arg_value_arrays(batch_keys_to_iteration_keys)
        batch_keys = batch_keys_to_iteration_keys.keys
        batch_keys_to_batch_values = @args.slice(*(batch_keys))

        batch_values = batch_keys_to_batch_values.values
        first_batch_value = batch_values.pop
        if batch_values.length > 0
          batch_values = first_batch_value.zip(batch_values)
        else
          batch_values = first_batch_value.zip
        end
        batch_values
      end
    end
  end
end
