module ManageEngine
  module Tracker
    
    class DefaultTracker
      
    attr_accessor :name, :error, :endtime, :starttime, :child, :sibling
      
      def initialize(name = "unknonwn", time = ManageEngine::APMObjectHolder.instance.util.currenttimemillis)
        @starttime = time.to_i
        @name = name
        @logger = ManageEngine::APMObjectHolder.instance.log
      end
      
      def finish(time = ManageEngine::APMObjectHolder.instance.util.currenttimemillis)
        @endtime = time.to_i
      end
      
      def error?
        @error != nil
      end
      
      def setError(exception)
        @error = exception
      end
      
      def setName(context)
        @name = context
      end
      
      def duration
        (@endtime - @starttime).to_i
      end
      
      def ==(obj)
        return obj != nil && @name == obj.name
      end
      
      def hash
        return @name.hash
      end
      
      def to_s
        @name
      end
      
      def getAdditionalInfo
        if error?
          {ManageEngine::APMObjectHolder.instance.constants.mf_exception_st => ManageEngine::APMObjectHolder.instance.util.formatStacktrace(@error.backtrace)}
        else
          nil
        end
      end
      
    end
    
  end
end