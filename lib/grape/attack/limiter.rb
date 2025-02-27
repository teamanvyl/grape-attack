require 'grape/attack/request'
require 'grape/attack/counter'

module Grape
  module Attack
    class Limiter

      attr_reader :request, :adapter, :counter

      def initialize(env, adapter = ::Grape::Attack.config.adapter)
        @request = ::Grape::Attack::Request.new(env)
        @adapter = adapter
        @counter = ::Grape::Attack::Counter.new(@request, @adapter)
      end

      def call!
        return if disable?
        return unless throttle?

        allowed, request_count = counter.test_and_set

        unless allowed
          fail ::Grape::Attack::RateLimitExceededError.new("API rate limit exceeded for #{request.client_identifier}.")
        end

        set_rate_limit_headers(request_count)
      end

      private

      def disable?
        ::Grape::Attack.config.disable.call
      end

      def throttle?
        request.throttle?
      end

      def set_rate_limit_headers(request_count)
        request.context.route_setting(:throttle)[:remaining] = [0, max_requests_allowed - request_count].max
      end

      def max_requests_allowed
        request.throttle_options.max.to_i
      end
    end
  end
end
