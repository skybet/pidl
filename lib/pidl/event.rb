module Pidl

  # Provide a simple multi-cast event subscription model
  #
  # Clients subscribe via on, passing a block. When an emit occurs, all blocks
  # subscribed are called.
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
    def on event, &block
      if subscribers[event].nil?
        subscribers[event] = [ block ]
      else
        subscribers[event].push block
      end
      self
    end

    # Emit an event to all listeners with optional args
    def emit event, *args
      if not subscribers[event].nil?
        subscribers[event].each do |s|
          s.call *args
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
