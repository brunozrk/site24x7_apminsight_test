require 'agent/server/instrument/rails'
require 'agent/server/instrument/sinatra'
require 'agent/server/instrument/active_record'
require 'agent/server/instrument/action_view'

module ManageEngine
  class Environment
    
    SUPPORTED_FRAMEWORKS = [
        ManageEngine::Instrumentation::RailsFramework.new,
        ManageEngine::Instrumentation::SinatraFramework.new
    ]
    
    DATABASE_INTERCEPTORS = [
        ManageEngine::Instrumentation::ActiveRecordSQL.new
    ]
    
    OTHER_INTERCEPTORS = [
        ManageEngine::Instrumentation::ActionView.new
    ]
    
    def detect_and_instrument
      @framework ||= SUPPORTED_FRAMEWORKS.detect{ |framework| framework.present? }
      @framework.instrument
      
      DATABASE_INTERCEPTORS.each do |interceptor|
        if (interceptor.present?)
          interceptor.instrument
        end
      end
      
      OTHER_INTERCEPTORS.each do |interceptor|
        if (interceptor.present?)
          interceptor.instrument
        end
      end
    end
    
  end
end
