require 'agent/am_objectholder'
require 'agent/trackers/root_tracker'

module ManageEngine
  module Instrumentation
    class SinatraFramework
      
      def present?
        defined?(::Sinatra) && defined?(::Sinatra::Base)
      end
      
      def version
        ::Sinatra::VERSION
      end
      
      def env
        ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      end
      
      def name
        'Sinatra'
      end
      
      def instrument
        ManageEngine::APMObjectHolder.instance.log.info "Instrumenting Sinatra framework. Version: #{version}"
        ::Sinatra::Base.class_eval do
          include ManageEngine::Instrumentation::APMInsightSinatra
          
          alias original_route_eval route_eval
          alias route_eval apminsight_route_eval
          
#          alias sinatra_exception_handler! handle_exception!
#          alias handle_exception! apminsight_exception_handler!
          
        end # class_eval
      end # def instrument
      
    end # class Sinatra
    
    module APMInsightSinatra
              
      def apminsight_route_eval(*args, &block)
        
        # http://www.rubydoc.info/github/rack/rack/master/Rack/Request
        url = (env.has_key?('sinatra.route') ? env['sinatra.route'] : @request.path).dup
        @obj = ManageEngine::APMObjectHolder.instance
        
        sinatraTracker = ManageEngine::Tracker::RootTracker.new(url)
        sinatraTracker.url=(url)
        sinatraTracker = ManageEngine::Agent::TrackerHandler.invokeTracker(sinatraTracker)
        
        # TODO: capture all additional details @request.query_string @request.params
        
        begin
          original_route_eval(*args, &block)
        
        rescue Exception => e  # On application error, above method throws exception
          if (sinatraTracker != nil)
            sinatraTracker.setError(e)
            sinatraTracker.setStatus(500) # By default, set 500 as status for error txns
          end
          raise e
        
        ensure
          if sinatraTracker != nil
            sinatraTracker.finish
          end
          ManageEngine::Agent::TrackerHandler.exitTracker(sinatraTracker)
        end
        
      end
      
#      def apminsight_exception_handler!(*args, &block)
#        begin
#          sinatra_exception_handler!(*args, &block)
#        ensure
#          tracker = Thread.current[:apminsight]
#          puts "tracker is #{(tracker == nil)}"
#          if tracker != nil
#            tracker.error(args[0]) # Other way, env[sinatra.error]
#            tracker.status(@response.status)
#            finishTracker tracker
#          end #if
#        end#begin
#      end#def
#      
#      def finishTracker(tracker)
#        tracker.finish
#        #ManageEngine::APMObjectHolder.instance.collector.updateTransaction(id,stats)
#        puts tracker.to_s
#        Thread.current[:apminsight] = nil
#      end
      
    end # module SinatraFramework
    
  end # module Instrumentation
end