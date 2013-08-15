# Allow a job's JID to be specified in Sidekiq::Client#push
module Sidekiq
  class Client
    class << self
      alias_method :original_normalize_item, :normalize_item

      def normalize_item(item)
        normalized_item = original_normalize_item(item)
        normalized_item['jid'] = item['jid'] if item['jid'].present?
        normalized_item
      end
    end
  end
end
