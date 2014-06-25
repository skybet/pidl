module Pidl

  # Simple lazy evaluation wrapper
  #
  # Provide a way to handle different lazy evaluation scenarios
  # through a single interface. Accepts "dumb" (non-callable) values
  # as well as lambdas and blocks. Evaluates them only when #value
  # is called explicitly, or implicitly during string coercion.
  #
  class Promise

    # Create a new Promise
    #
    # Accepts a dumb value, lambda or block. Raises ArgumentError
    # if a value and a block are both provided.
    #
    def initialize v=nil, context=nil, &block
      @promise = v
      @context = context
      @value = nil
      if block_given?
        if not v.nil?
          raise ArgumentError.new "Cannot specify value and block for Promise"
        end
        @promise = block
      end
    end

    # True if evaluation has already occurred
    #
    # Always true for dumb values. Only true for callables after
    # they are evaluated the first time.
    def evaluated?
      if @promise.respond_to? :call or @promise.is_a? Symbol
        not @value.nil?
      else
        true
      end
    end

    # Return the evaluated value of this Promise
    #
    # Evaluates if not already evaluated
    #
    def value
      @value || __eval
    end

    # Return the source of this promise in whatever
    # form it takes
    #
    def desc
      if evaluated?
        value
      elsif @promise.is_a? Symbol and @context
        ":#{@promise.to_s}"
      elsif @promise.respond_to? :call
        "{block}"
      else
        @promise.to_s
      end
    end

    # Convert to string
    #
    # Calls #value implicitly
    #
    def to_str
      to_s
    end

    # Return string representation
    #
    # Calls #value implicitly
    def to_s
      value.to_s
    end

    private

    def __eval
      if @promise.is_a? Symbol and @context
        @value = @context.get @promise
      elsif @promise.respond_to? :call
        @value = @promise.call
      else
        @value = @promise
      end
      @value
    end

  end

end
