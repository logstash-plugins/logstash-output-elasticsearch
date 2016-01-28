require 'concurrent'
java_import java.util.concurrent.locks.ReentrantLock

module LogStash; module Outputs; class ElasticSearch
  class Buffer
    def initialize(logger, max_size, flush_interval, &block)
      @logger = logger
      # You need to aquire this for anything modifying state generally
      @operations_mutex = Mutex.new
      @operations_lock = java.util.concurrent.locks.ReentrantLock.new

      @stopping = Concurrent::AtomicBoolean.new(false)
      @max_size = max_size
      @submit_proc = block

      @buffer = []

      @last_flush = Time.now
      @flush_interval = flush_interval
      @flush_thread = spawn_interval_flusher
    end

    def push(item)
      synchronize do |buffer|
        push_unsafe(item)
      end
    end
    alias_method :<<, :push

    # Push multiple items onto the buffer in a single operation
    def push_multi(items)
      raise ArgumentError, "push multi takes an array!, not an #{items.class}!" unless items.is_a?(Array)
      synchronize do |buffer|
        items.each {|item| push_unsafe(item) }
      end
    end

    def flush
      synchronize { flush_unsafe }
    end

    def stop(do_flush=true,wait_complete=true)
      return if stopping?
      @stopping.make_true

      # No need to acquire a lock in this case
      return if !do_flush && !wait_complete

      synchronize do
        flush_unsafe if do_flush
        @flush_thread.join if wait_complete
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

    def push_unsafe(item)
      @buffer << item
      if @buffer.size >= @max_size
        flush_unsafe
      end
    end

    def spawn_interval_flusher
      Thread.new do
        loop do
          sleep 0.2
          break if stopping?
          synchronize { interval_flush }
        end
      end
    end

    def interval_flush
      if last_flush_seconds_ago >= @flush_interval
        begin
          @logger.debug? && @logger.debug("Flushing buffer at interval",
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
        rescue Exception => e
          @logger.warn("Exception flushing buffer at interval!", :error => e.message, :class => e.class.name)
        end
      end
    end

    def flush_unsafe
      if @buffer.size > 0
        @submit_proc.call(@buffer)
        @buffer.clear
      end

      @last_flush = Time.now # This must always be set to ensure correct timer behavior
    end

    def last_flush_seconds_ago
      Time.now - @last_flush
    end

    def stopping?
      @stopping.true?
    end
  end
end end end