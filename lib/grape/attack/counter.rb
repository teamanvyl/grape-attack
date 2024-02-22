module Grape
  module Attack
    class Counter

      attr_reader :request, :adapter

      def initialize(request, adapter)
        @request = request
        @adapter = adapter
      end

      def test_and_set
        @value ||= begin
          adapter.test_and_set(key, max_requests_allowed, ttl_in_seconds)
        rescue ::Grape::Attack::StoreError
          [1, 1]
        end
      end

      private

      def max_requests_allowed
        request.throttle_options.max.to_i
      end

      def key
        request.client_identifier.to_s
      end

      def ttl_in_seconds
        request.throttle_options.per.to_i
      end
    end
  end
end
