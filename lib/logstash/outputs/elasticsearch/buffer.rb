require "concurrent"

module LogStash; module Outputs; class ElasticSearch
  class Buffer
    def initialize(logger, max_size, flush_interval, &block)
      @logger = logger
      # You need to aquire this for anything modifying state generally
      @operations_mutex = Mutex.new

      @state = :running
      @max_size = max_size
      @submit_proc = block

      @buffer = []

      @last_flush = Time.now
      @flush_interval = flush_interval
      @flush_thread = spawn_interval_flusher
    end

    def push(item)
      synchronize do |buffer|
        buffer << item
        if buffer.size >= @max_size
          flush_unsafe
        end
      end
    end
    alias_method :<<, :push

    # Push multiple items onto the buffer in a single operation
    def push_multi(items)
      raise ArgumentError, "push multi takes an array!, not an #{items.class}!" unless items.is_a?(Array)
      synchronize do |buffer|
        buffer.concat(items)
      end
    end

    def flush
      synchronize { flush_unsafe }
    end

    def stop
      synchronize do
        @state = :stopping
        @flush_thread.join
      end
    end

    def contents
      synchronize {|buffer| buffer}
    end

    # For externally operating on the buffer contents
    # this takes a block and will yield the internal buffer and executes
    # the block in a synchronized block from the internal mutex
    def synchronize
      @operations_mutex.synchronize { yield(@buffer) }
    end

    # These methods are private for various reasons, chief among them threadsafety!
    # Many require the @operations_mutex to be locked to be safe
    private

    def spawn_interval_flusher
      Thread.new do
        loop do
          sleep 0.2
          break if stopping?

          synchronize do
            if last_flush_seconds_ago >= @flush_interval
              begin
                @logger.info? && @logger.info("Flushing buffer at interval",
                                              :instance => self.inspect,
                                              :interval => @flush_interval)
                flush_unsafe
              rescue StandardError => e
                @logger.warn("Error flushing buffer at interval!",
                             :instance => self.inspect,
                             :message => e.message,
                             :class => e.class.name,
                             :backtrace => e.backtrace
                )
              end
            end
          end
        end
      end
    end

    def flush_unsafe
      @submit_proc.call(@buffer)
      @last_flush = Time.now
      @buffer.clear
    end

    def last_flush_seconds_ago
      Time.now - @last_flush
    end

    def running?
      @state == :running
    end

    def stopping?
      @state == :stopping
    end
  end
end end end