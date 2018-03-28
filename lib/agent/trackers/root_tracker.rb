require 'agent/trackers/default_tracker'

module ManageEngine
  module Tracker
    class RootTracker < DefaultTracker
      
      attr_accessor :status, :url
      
      def url=(url = "unknown")
        @url = ManageEngine::APMObjectHolder.instance.txn_util.normalizeName(url)
      end
      
      def http_method(method)
        @http_method = method
      end
      
      def http_params(params)
        @http_params = params
      end
      
      def queryString(querystring)
        @queryString = querystring
      end
      
      def setStatus(httpcode)
        @status = httpcode
      end
      
      def getAdditionalInfo
        info = super
        if (@http_method != nil && @queryString != nil && @status != nil)
          if (info == nil)
            info = Hash.new
          end
          info["http_method_name"] = @http_method
          info["http_query_str"] = @queryString
          info["httpcode"] = @status
        end
        info
      end
    end
  end
end