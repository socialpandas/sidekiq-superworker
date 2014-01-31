# We need to be able to inject the jid for a job when we call Sidekiq::Client#push.
# Sidekiq didn't support this prior to 2.12.2, so we need to add support for it to
# those versions.
if Gem::Version.new(Sidekiq::VERSION) < Gem::Version.new('2.12.2')
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
end
