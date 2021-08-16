module Manticore
  class Client
    def pool(options = {})
      @pool ||= begin
        @max_pool_size = options.fetch(:pool_max, DEFAULT_MAX_POOL_SIZE)
        pool_builder(options).tap do |cm|
          cm.set_validate_after_inactivity options.fetch(:check_connection_timeout, 2_000)
          cm.set_default_max_per_route options.fetch(:pool_max_per_route, @max_pool_size)
          cm.set_max_total @max_pool_size

          socket_config_builder = SocketConfig.custom
          socket_config_builder.set_so_timeout(options.fetch(:socket_timeout, DEFAULT_SOCKET_TIMEOUT) * 1000)
          socket_config_builder.set_tcp_no_delay(options.fetch(:tcp_no_delay, true))
          cm.set_default_socket_config socket_config_builder.build

          finalize cm, :shutdown
        end
      end
    end
  end
end