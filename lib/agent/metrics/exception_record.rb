module APMInsight
  module Errors
    class ExceptionRecord
      
      attr_reader :time, :message, :exception
      
      def initialize(exception, time = Time.now)
        @time = time.to_f * 1000;
        @message = exception.message
        @exception = exception
      end
      
      def ==(obj)
        return obj != nil && @exception == obj.exception
      end
      
      def hash
        return @exception.hash
      end
      
      
    end
  end
end