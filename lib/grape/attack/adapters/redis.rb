require 'redis-namespace'

module Grape
  module Attack
    module Adapters
      class Redis

        attr_reader :broker

        def initialize
          @broker = ::Redis::Namespace.new("grape-attack:#{env}:throttle", redis: ::Redis.new(url: url))
        end

        def test_and_set(key, max_requests_allowed, ttl_in_seconds)
          with_custom_exception do
            namespaced_key = "#{broker.namespace}:#{key}"

            # A tuple is returned, the first element is if the requet is allowed and the second
            # is the number of requests made in the window
            broker.eval(<<~CMD)
              local current_time = redis.call('TIME')
              local trim_time = tonumber(current_time[1]) - #{ttl_in_seconds.to_i}
              redis.call('ZREMRANGEBYSCORE', '#{namespaced_key}', 0, trim_time)
              local request_count = redis.call('ZCARD', '#{namespaced_key}')
              if request_count < #{max_requests_allowed} then
                redis.call('ZADD', '#{namespaced_key}', current_time[1], current_time[1] .. current_time[2])
                redis.call('EXPIRE', '#{namespaced_key}', #{ttl_in_seconds.to_i})
                return { true, request_count + 1 }
              end
              return { false, request_count }
            CMD
          end
        end

        private

        def with_custom_exception(&block)
          block.call
        rescue ::Redis::BaseError => e
          raise ::Grape::Attack::StoreError.new(e.message)
        end

        def env
          if defined?(::Rails)
            ::Rails.env
          elsif defined?(RACK_ENV)
            RACK_ENV
          else
            ENV['RACK_ENV']
          end
        end

        def url
          ENV['REDIS_URL'] || 'redis://localhost:6379/0'
        end

      end
    end
  end
end
