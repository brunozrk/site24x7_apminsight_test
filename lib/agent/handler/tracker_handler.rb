require 'agent/handler/sequence_book'

module ManageEngine
  module Agent
    class TrackerHandler
      
      def self.invokeTracker tracker
        begin
          @obj = ManageEngine::APMObjectHolder.instance
          
          if !@obj.config.agent_enabled || tracker == nil
            return nil
          end
          
          seqBook = Thread.current[:apminsight]
          if seqBook != nil
            if seqBook.listenFlag == 1
              return nil
            end
          else
            seqBook = ::APMInsight::Agent::SequenceBook.new
            Thread.current[:apminsight] = seqBook
          end
          
          tracker = seqBook.attachTracker(tracker)
          
          return tracker
        rescue Exception=>ex
          # Logging to be done here, Not sure whether its safe to do
          if (@obj != nil)
            @obj.log.logException "[TrackerHandler] Exception occurred at invoketracker.", ex
          end
          return nil
        end
      end
      
      
      # Closes tracker properly and set everything ready to process next tracker
      # If roottracker closes, sequence book is cleaned and data are push to store
      def self.exitTracker tracker
        begin
          if tracker != nil
            seqBook = Thread.current[:apminsight]
            if seqBook != nil
              seqBook.closeTracker tracker
            end
          end
        rescue Exception=>ex
          if (@obj != nil)
            @obj.log.logException "[TrackerHandler] Exception occurred at exittracker.", ex
          end
        end
      end
      
    end # Class TrackerHandler
    
  end # module Agent
end