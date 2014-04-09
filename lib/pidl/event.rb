module Pidl

  # Provide a simple multi-cast event subscription model
  #
  # Clients subscribe via on, passing a block. When an emit occurs, all blocks
  # subscribed are called.
  #
  # Emitted events have at least one parameter; the event itself. Any other
  # parameters passed to #emit are put on the end.
  #
  # For example:
  #
  #   thing.on :test do |event, name|
  #     puts "#{event} => #{name}"
  #   end
  #   thing.emit :event, "jim"
  #
  # would result in the following output:
  #
  #   test => jim
  #
  module EventEmitter

    # A hash containing all currently subscribed events and a list of
    # subscribers to each event
    def subscribers
      if @__event_subscribers__.nil?
        @__event_subscribers__ = {}
      end
      @__event_subscribers__
    end

    # Subscribe to an event with a given block
    #
    # When an emit occurs on that event, the block is called
    #
    def on event, handler=nil, &block
      if not handler.nil? and block_given?
        raise ArgumentError.new "Cannot specify lambda and block together"
      end

      if not handler.nil? and not handler.respond_to? :call
        raise ArgumentError.new "Handler must be callable"
      end

      if handler.nil?
        handler = block
      end

      if subscribers[event].nil?
        subscribers[event] = [ handler ]
      else
        subscribers[event].push handler
      end

      # return the handler
      handler
    end

    # Emit an event to all listeners with optional args
    def emit event, *args
      if not subscribers[event].nil?
        subscribers[event].each do |s|
          s.call event, *args
        end
      end
      self
    end

    # Unsubscribe a listener from an event
    def removeListener event, listener
      if not subscribers[event].nil?
        subscribers[event] = subscribers[event].select { |l| l != listener }
      end
      self
    end

  end

end
