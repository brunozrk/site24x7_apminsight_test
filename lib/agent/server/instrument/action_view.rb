require 'agent/am_objectholder'
require 'agent/trackers/default_tracker'
require 'agent/handler/tracker_handler'

module ManageEngine
  module Instrumentation
    class ActionView
      
      def present?
        defined?(::Rails)
      end
      
      def name
        'ActiveView'
      end
      
      def instrument
        @obj = ManageEngine::APMObjectHolder.instance
        @obj.log.info "Instrumenting ActiveView"
        
        ActiveSupport::Notifications.subscribe('render_template.action_view') do |name, start, finish, id, payload|
          collect_data(name, start, finish, payload)
        end ## subscribe
        
        ActiveSupport::Notifications.subscribe('render_partial.action_view') do |name, start, finish, id, payload|
          collect_data(name, start, finish, payload)
        end ## subscribe
        
        ActiveSupport::Notifications.subscribe('render_collection.action_view') do |name, start, finish, id, payload|
          collect_data(name, start, finish, payload)
        end ## subscribe
        
      end  ## def instrument
      
      def collect_data(name, start, finish, payload)
        begin
          
          if name != 'render_template.action_view'
            name = "Partial # #{payload[:identifier]}"
          else
            name = "Rendering # #{payload[:identifier]}"
          end
          
          tracker = ManageEngine::Tracker::DefaultTracker.new(name, start.to_f * 1000)
          tracker = ManageEngine::Agent::TrackerHandler.invokeTracker(tracker)
          
          if tracker != nil
            tracker.finish(finish.to_f * 1000)
            
            exception = payload[:exception_object]
            if exception != nil
              tracker.setError(exception)
            end
            
            ManageEngine::Agent::TrackerHandler.exitTracker(tracker)
          end
        rescue Exception => e
          @obj.log.logException("Error processing #{name} payload", e)
        end
      end ## def collect_data
      
    end ## class ActionView
  end
end