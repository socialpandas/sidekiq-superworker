module Sidekiq
  module Superworker
    class Subjob
      include ActiveModel::Validations
      include ActiveModel::Naming

      ATTRIBUTES = [:subjob_id, :superjob_id, :parent_id, :children_ids, :next_id, :children_ids,
        :subworker_class, :superworker_class, :arg_keys, :arg_values, :status, :descendants_are_complete,
        :meta]

      attr_accessor *ATTRIBUTES

      validates_presence_of :subjob_id, :subworker_class, :superworker_class, :status

      class << self
        def create(attributes={})
          if attributes.is_a?(Array)
            attributes.collect { |attribute| create(attribute) }
          else
            object = new(attributes)
            object.save
            object
          end
        end

        def find_by_jid(jid)
          hash = Sidekiq.redis do |conn|
            conn.hgetall("#{redis_prefix}:#{jid}")
          end
          return nil if hash.blank?
          hash.collect do |key, value|
            hash[key] = ActiveSupport::JSON.decode(value)
          end
          new(hash)
        end

        def find_by_key(key)
          return nil if key.blank?
          jid = key.split(':', 2).last
          find_by_jid(jid)
        end

        def find_by_superjob_jid(jid)
          keys = Sidekiq.redis do |conn|
            conn.keys("#{redis_prefix}:#{jid}:*")
          end
          keys.collect { |key| find_by_key(key) }
        end

        def all
          keys.collect { |key| find_by_key(key) }
        end

        def count
          keys.length
        end

        def keys
          Sidekiq.redis do |conn|
            conn.keys("#{redis_prefix}:*")
          end
        end

        def delete_subjobs_for(superjob_id)
          Sidekiq.redis do |conn|
            key = self.jid(superjob_id, '*')
            keys = conn.keys("#{redis_prefix}:#{key}")
            conn.del(keys) if keys.any?
          end
        end

        def transaction(&block)
          result = nil
          Sidekiq.redis do |conn|
            conn.multi do
              result = yield
            end
          end
          result
        end

        def jid(superjob_id, subjob_id)
          "#{superjob_id}:#{subjob_id}"
        end

        def redis_prefix
          Superworker.options[:subjob_redis_prefix]
        end
      end

      def initialize(params={})
        if params.present?
          params.each do |attribute, value|
            self.public_send("#{attribute}=", value)
          end
        end
      end

      def save
        return false unless self.valid?
        Sidekiq.redis do |conn|
          conn.mapped_hmset(key, to_param)
        end
        true
      end

      def update_attributes(pairs = {})
        pairs.each_pair { |attribute, value| send("#{attribute}=", value) }
        self.save
      end

      def update_attribute(attribute, value)
        send("#{attribute.to_s}=", value)
        return false unless self.valid?
        Sidekiq.redis do |conn|
          conn.hset(key, attribute.to_s, value.to_json)
        end
        true
      end

      def jid
        self.class.jid(superjob_id, subjob_id)
      end

      def key
        "#{self.class.redis_prefix}:#{jid}"
      end

      def descendants_are_complete
        @descendants_are_complete || false
      end

      def parent
        self.class.find_by_jid(self.class.jid(superjob_id, parent_id))
      end

      def children
        return [] if children_ids.blank?
        children = children_ids.collect { |id| self.class.find_by_jid(self.class.jid(superjob_id,id)) }
        children.reject(&:nil?)
      end

      def next
        self.class.find_by_jid(self.class.jid(superjob_id,next_id))
      end

      def ==(other)
        self.jid == other.jid
      end

      def to_info
        "Subjob ##{jid} (#{superworker_class} > #{subworker_class})"
      end

      def to_param
        param = {}
        ATTRIBUTES.each do |attribute|
          param["#{attribute.to_s}".to_sym] = send(attribute).to_json
        end
        param
      end
    end
  end
end
