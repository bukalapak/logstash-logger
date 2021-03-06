require 'logstash-logger/buffer'

module LogStashLogger
  module Device
    class Connectable < Base
      include LogStashLogger::Buffer

      attr_accessor :buffer_logger

      def initialize(opts = {})
        super

        if opts[:batch_events]
          warn "The :batch_events option is deprecated. Please use :buffer_max_items instead"
        end

        if opts[:batch_timeout]
          warn "The :batch_timeout option is deprecated. Please use :buffer_max_interval instead"
        end

        @buffer_group = nil
        @buffer_max_items = opts[:batch_events] || opts[:buffer_max_items]
        @buffer_max_interval = opts[:batch_timeout] || opts[:buffer_max_interval]
        @drop_messages_on_flush_error =
          if opts.key?(:drop_messages_on_flush_error)
            opts.delete(:drop_messages_on_flush_error)
          else
            false
          end

        @drop_messages_on_full_buffer =
          if opts.key?(:drop_messages_on_full_buffer)
            opts.delete(:drop_messages_on_full_buffer)
          else
            true
          end

        @buffer_flush_at_exit =
          if opts.key?(:buffer_flush_at_exit)
            opts.delete(:buffer_flush_at_exit)
          else
            true
          end

        @buffer_logger = opts[:buffer_logger]

        @buffer_on_full_callback = opts[:buffer_on_full_callback]

        buffer_initialize(
          max_items: @buffer_max_items,
          max_interval: @buffer_max_interval,
          logger: buffer_logger,
          autoflush: @sync,
          drop_messages_on_flush_error: @drop_messages_on_flush_error,
          drop_messages_on_full_buffer: @drop_messages_on_full_buffer,
          flush_at_exit: @buffer_flush_at_exit
        )
      end

      def write(message)
        buffer_receive message, @buffer_group
      end

      def flush(*args)
        if args.empty?
          buffer_flush
        else
          messages, group = *args
          write_batch(messages, group)
        end
      end

      def on_full_buffer_receive(data)
        log_warning("Buffer Full - #{data}")
        @buffer_on_full_callback.call(data)
      end

      def close(opts = {})
        if opts.fetch(:flush, true)
          buffer_flush(final: true)
        end

        super
      end

      def to_io
        with_connection do
          super
        end
      end

      def connected?
        !!@io
      end

      def write_one(message)
        with_connection do
          super
        end
      end

      def write_batch(messages, group = nil)
        with_connection do
          super
        end
      end

      # Implemented by subclasses
      def connect
        fail NotImplementedError
      end

      def reconnect
        close(flush: false)
        connect
      end

      # Ensure the block is executed with a valid connection
      def with_connection(&block)
        connect unless connected?
        yield
      rescue => e
        log_error(e)
        close(flush: false)
        raise
      end
    end
  end
end
