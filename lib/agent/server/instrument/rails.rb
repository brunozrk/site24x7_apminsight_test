require 'agent/handler/tracker_handler'

module ManageEngine
  module Instrumentation
    class RailsFramework
      
      def present?
        defined?(::Rails) && defined?(::ActionController)
      end
      
      def version
        Rails::VERSION::STRING
      end
      
      def env
        if Rails::VERSION::MAJOR >= 3 
          ::Rails.env
        else
          RAILS_ENV.dup
        end
      end
      
      def name
        'Rails'
      end
      
      def instrument
        @obj = ManageEngine::APMObjectHolder.instance
        @obj.log.info "Instrumenting ActionController.. Rails Version: #{version}"
        @railsTracker = nil
        
        ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |name, start, finish, id, payload|
          path = payload[:path].partition("?")[0]
          @railsTracker = ManageEngine::Tracker::RootTracker.new("#{payload[:controller]}.#{payload[:action]}", start.to_f * 1000)
          @railsTracker.url=(path)
          @railsTracker = ManageEngine::Agent::TrackerHandler.invokeTracker(@railsTracker)
        end # subscribe
        
        
        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, start, finish, id, payload|
          if @railsTracker != nil
            @railsTracker.finish(finish.to_f * 1000)
            exception = payload[:exception_object]
            if exception != nil
              @railsTracker.setError(exception)
              @railsTracker.setStatus(500) # By default, set 500 as status for error txns
            end
            ManageEngine::Agent::TrackerHandler.exitTracker(@railsTracker)
          end
        end
        
      end # def instrument
      
    end
  end
end