require 'agent/handler/custom_api_handler'

module APMInsight
  module API
    module CustomTracker
      
      def self.included clazz
        clazz.extend CustomMethodTracker
      end
      
      module CustomMethodTracker
        # @api public
        def track_method(method_name)
          
          # Check whether the method exists
          return unless method_defined?(method_name) || private_method_defined?(method_name)
          
          # Check whether the method is already instrumented
          return if is_instrumented?(method_name)
          
          # Injecting code into the class
          class_eval(get_instrumentation_code(method_name), __FILE__, __LINE__)
          
          # Setting alias to invoke agent methods
          alias_method "original_#{method_name}", "#{method_name}"
          alias_method "#{method_name}", "apminsight_#{method_name}"
          
          # TODO: set visibility 
  #        visibility = instance_method_visibility(self, method_name)
  #        send visibility, method_name
  #        send visibility, "apminsight_#{method_name}"
        end
        
        
        def is_instrumented?(method_name)
          method_name = "apminsight_#{method_name}"
          return method_defined?(method_name)
        end
        
        # TODO: Capture exception, attach tracker
        # TODO: Create agent handler and call respective methods like in java agent
        def get_instrumentation_code(method_name)
          "def apminsight_#{method_name}(*args, &block)
              tracker = ::APMInsight::API::CustomAPIHandler.invokeTracker \"\#{self.class.name}.#{method_name}\"
              begin
                original_#{method_name}(*args, &block)
              rescue Exception=>e
                if tracker != nil
                  tracker.setError e
                end
                raise e
              ensure
                ::APMInsight::API::CustomAPIHandler.exitTracker tracker
              end
          end"
        end
        
#        def instance_method_visibility(klass, method_name)
#          if klass.private_instance_methods.map{|s|s.to_sym}.include? method_name.to_sym
#            :private
#          elsif klass.protected_instance_methods.map{|s|s.to_sym}.include? method_name.to_sym
#            :protected
#          else
#            :public
#          end
#        end
      end #CustomMethodTracker
      
      def self.trackException(exception)
        return unless exception != nil
        
        # Check for active transaction
        # Associate exception to current transaction
        ::APMInsight::API::CustomAPIHandler.track_exception(exception)
      end
      
    end #CustomTracker
  end #API
end