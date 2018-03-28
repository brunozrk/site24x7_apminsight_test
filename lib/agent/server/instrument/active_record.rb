require 'agent/am_objectholder'
require 'agent/trackers/database_tracker'
require 'agent/handler/tracker_handler'

module ManageEngine
  module Instrumentation
    class ActiveRecordSQL
      
      def present?
        defined?(::ActiveRecord::Base) && defined?(::ActiveSupport::Notifications)
      end
      
      def name
        'ActiveRecord'
      end
      
      def instrument
        @obj = ManageEngine::APMObjectHolder.instance
        @obj.log.info "Instrumenting ActiveRecord"
        
        ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
          begin 
            if @obj.config.sql_capture && payload[:name] != "SCHEMA" # Dropping internal schema related queries
              dbTracker = ManageEngine::Tracker::DatabaseTracker.new(payload[:name], start.to_f * 1000)
              dbTracker.sql(payload[:sql])
              dbTracker.params(payload[:binds])
              dbTracker = ManageEngine::Agent::TrackerHandler.invokeTracker(dbTracker)
              
              if dbTracker != nil
                dbTracker.finish(finish.to_f * 1000)
                
                if dbTracker.duration >= (@obj.config.sql_trace_t.to_f * 1000)
                  dbTracker.sqlBacktrace(caller(10))
                end
                
                exception = payload[:exception_object]
                if exception != nil
                  dbTracker.setError(exception)
                end
                
                ManageEngine::Agent::TrackerHandler.exitTracker(dbTracker)
              end
            end
          rescue Exception => e
            @obj.log.logException("Error processing #{name} payload", e)
          end
        end #subscribe
      end #def instrument
      
    end #class ActiveRecordSQL
  end
end