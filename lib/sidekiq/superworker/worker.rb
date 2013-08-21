module Sidekiq
  module Superworker
    class Worker
      def self.create(*args, &block)
        class_name = args.shift.to_sym
        nested_hash = DSLParser.parse(block)
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

        Object.const_set(class_name, klass)
      end
    end
  end
end
