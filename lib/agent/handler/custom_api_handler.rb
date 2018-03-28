require 'agent/handler/sequence_book'

module APMInsight
  module API
    class CustomAPIHandler
      
      ## Create tracker for custom instrumented methods and send them to tracker handler
      def self.invokeTracker name
        begin
#          @obj = ManageEngine::APMObjectHolder.instance
                  
          if Thread.current[:apminsight] != nil
            tracker = ManageEngine::Tracker::DefaultTracker.new(name)
            tracker = ManageEngine::Agent::TrackerHandler.invokeTracker(tracker)
            return tracker
          end
          
          return nil
        rescue Exception=>e
          return nil
        end
      end
      
      def self.exitTracker tracker
        if tracker != nil
          tracker.finish
          ManageEngine::Agent::TrackerHandler.exitTracker(tracker)
        end
      end
      
      def self.track_exception exception
        seqBook = Thread.current[:apminsight]
        if seqBook != nil
          seqBook.addExceptionInfo exception
        end
      end
      
    end #class CustomAPIhandler
  end #module API
end