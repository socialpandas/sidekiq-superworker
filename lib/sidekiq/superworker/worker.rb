module Sidekiq
  module Superworker
    class Worker
      def self.create(*args, &block)
        class_name = args.shift.to_sym
        dsl = DSLParser.parse(block)
        create_class(class_name, args, dsl)
      end

      protected

      def self.create_class(class_name, arg_keys, dsl)
        klass = Class.new do
          @class_name = class_name
          @arg_keys = arg_keys
          @records = dsl[:records]
          @nested_records = dsl[:nested_records]

          class << self
            attr_reader :nested_records

            def is_a_superworker?
              true
            end

            def perform_async(*arg_values)
              @args = Hash[@arg_keys.zip(arg_values)]
              subjobs = create_subjobs
              SuperjobProcessor.create(@superjob_id, @class_name, arg_values, subjobs)
            end

            protected

            def create_subjobs
              @superjob_id = SecureRandom.hex(12)
              @records.collect do |id, record|
                record[:status] = 'initialized'
                record[:superjob_id] = @superjob_id
                record[:superworker_class] = @class_name
                record[:arg_values] = record[:arg_keys].collect do |arg_key|
                  # Allow for subjob arg_values to be set within the superworker definition; if a symbol is
                  # used in the DSL, use @args[arg_key], and otherwise use arg_key as the value
                  arg_key.is_a?(Symbol) ? @args[arg_key] : arg_key
                end
                Sidekiq::Superworker::Subjob.create(record)
              end
            end
          end
        end

        Object.const_set(class_name, klass)
      end
    end
  end
end
