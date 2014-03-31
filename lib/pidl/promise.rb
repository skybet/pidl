module Pidl

  class Promise

    def initialize v=nil, &block
      @promise = v
      @value = nil
      if block_given?
        if not v.nil?
          raise ArgumentError.new "Cannot specify value and block for Promise"
        end
        @promise = block
      end
    end

    def value
      @value || __eval
    end

    private

    def __eval
      if @promise.respond_to? :call
        @value = @promise.call
      else
        @value = @promise
      end
      @value
    end

  end

end
