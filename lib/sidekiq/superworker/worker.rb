module Sidekiq
  module Superworker
    class Worker
      def self.create(*args, &block)
        class_name = args.shift.to_sym
        nested_hash = DSLParser.new.parse(block)
        create_class(class_name, args, nested_hash)
      end

      protected

      def self.create_class(class_name, arg_keys, nested_hash)
        klass = Class.new(Sidekiq::Superworker::WorkerClass) do
          @class_name = class_name
          @arg_keys = arg_keys
          @nested_hash = nested_hash
          @dsl_hash = DSLHash.new
        end

        class_components = class_name.to_s.split('::')
        class_name = class_components.pop
        module_name = class_components.join('::')

        if module_name.empty?
          Object.const_set(class_name, klass)
        else
          module_name.constantize.const_set(class_name, klass)
        end
      end
    end
  end
end
