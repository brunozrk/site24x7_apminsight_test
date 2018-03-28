require 'agent/metrics/exception_record'

module APMInsight
  module Agent
    class SequenceBook
      attr_reader :openTracker, :closedTracker, :rootTracker, :trackerCount, :exceptionBag, :listenFlag
      
      def initialize
        @rootTracker = createDummyTracker()
        @closedTracker = @rootTracker
        @openTracker = nil
        
        @trackerCount = 0
        @listenFlag = -1
#        @exceptionBag = Array.new
      end
      
      def attachTracker tracker
        if tracker == nil
          return nil
        end
        
        # If RootTracker is not set, check type and set
        if @rootTracker == @closedTracker
          if !tracker.is_a?(ManageEngine::Tracker::RootTracker)
            closeSequence()
            return nil
          end
          @rootTracker = tracker
          
          updateListenFlag()
        end
        
        
        # Attach tracker as Sibling or Child and set nominee
        if @closedTracker != nil
          tracker.sibling = @closedTracker
          @closedTracker.sibling = tracker # Nominee - if dropped/corrupted, defaults to this tracker
          @openTracker = tracker
          @closedTracker = nil
        else
          if tracker.equal?(@openTracker)
            return nil
          end
          
          @openTracker.child = tracker
          tracker.sibling = @openTracker
          @openTracker = tracker
        end
        
        checkAndArrestSequence()
        
        return tracker
      end
      
      def closeTracker tracker
        @closedTracker = tracker
        tracker.sibling = nil
        @openTracker = nil
        
        # Marks end of transaction
        if @rootTracker == tracker
          if @listenFlag < 1 || (@listenFlag >= 1 && @trackerCount > 1)
            
            sequenceBag = Hash.new
            sequenceBag["roottracker"] = @rootTracker
            sequenceBag["exceptions"] = @exceptionBag
            
            ManageEngine::APMObjectHolder.instance.collector.updateTransaction(@rootTracker.url, sequenceBag)
          end
          closeSequence()
        end
      end
      
      def closeSequence
        @rootTracker = nil
        @openTracker = @closedTracker = nil
        @trackerCount = 0
        Thread.current[:apminsight] = nil
      end
      
      def addExceptionInfo(exception)
        begin
          if @exceptionBag == nil
            @exceptionBag = Set.new
          end
          exceptionRecord = ::APMInsight::Errors::ExceptionRecord.new(exception)
          @exceptionBag.add(exceptionRecord)
        rescue Exception=>e
        end
      end
      
      def updateListenFlag
        if !ManageEngine::APMObjectHolder.instance.txn_util.listen?(@rootTracker.url())
          @listenFlag = 1
        end
        
        ## Check for sampling factor & for bg txn chk if enabled
      end
      
      def checkAndArrestSequence
        if ++@trackerCount == 1000
          @listenFlag = 1
        end
        
        ## Can check for timeout
      end
      
      def createDummyTracker
        return ManageEngine::Tracker::DefaultTracker.new("dummy")
      end
      
    end
  end
end