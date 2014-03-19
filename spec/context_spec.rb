require 'pidl'
require 'lazy'
require 'context_behaviour'

include Pidl

describe Context do
  it_behaves_like 'Context'

  def context_instance *args
    Context.send :new, *args
  end

end
