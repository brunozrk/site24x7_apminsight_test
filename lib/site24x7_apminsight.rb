require "agent/server/instrument/am_apm"
require "agent/am_objectholder"
module ManageEngine
  # Starts a new thread to initialize the agent gem
#  Thread.new do
    ManageEngine::APMObjectHolder.instance 
#  end
end
