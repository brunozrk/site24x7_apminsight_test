##
##
# Currently disabling this class, since it will be called for every class's instance creation (Class.new is aliased here)
# This can be used for custom instrumentation.
##
##




#require 'agent/am_objectholder'
#@obj = ManageEngine::APMObjectHolder.instance
#class Class
#   alias old_new new
#   def new(*args, &block)
#	 result =nil;
#	 begin
#		if(block==nil || block=="")
#     		result = old_new(*args)
#		elsif
#     		result = old_new(*args,&block)
#		end
#	 rescue Exception=>exe
#        raise exe		 
#		result = self
#	 end
#	 me_apm_injector(self,result)
#	 
#		return result
#	 end
# end
#
#def me_apm_injector(s,result)
#	begin
#		if(ManageEngine::APMObjectHolder.instance.config.include_packages.index(s.name)!=nil)
#		ms =s.instance_methods(false)
#		cms = s.methods(false)
#		begin
#			ms.each do |m|
#			if( m.to_s.index("APMTEST"))
#				return;
#			end
#			end
#			cms.each do |m|
#			if( m.to_s.index("APMTEST"))
#				return;
#			end
#			end
#		rescue Exception=>e
#			return;
#		end
#		ManageEngine::APMObjectHolder.instance.log.debug "Injection Method : #{ms} "
#		ManageEngine::APMObjectHolder.instance.log.debug "Injection Class Method : #{cms} "
#		ms.each do |m|
#		mn = m.to_s
#		#ManageEngine::APMObjectHolder.instance.log.info "ManageEngine Monitor Method : #{s.name} # #{m.to_s}"
#		omn = "APMTEST"+mn+"APMTEST"
#		s.class_eval  %{
#			alias_method :#{omn}, :#{mn}
#		def #{mn} *args, &block
#			begin
#			ActiveSupport::Notifications.instrument("apm.methodstart", {:method=>"#{mn}",:args=>args})
#			res = #{omn} *args, &block
#			ActiveSupport::Notifications.instrument("apm.methodend", {:method=>"#{mn}",:args=>args})
#			return res
#			rescue Exception => exe
#			puts "error in calling method"
#			raise exe
#			ensure
#			end
#			end
#		}
#		end#do
#		default_methods = Array.new
#		default_methods.push("_helpers");
#		default_methods.push("middleware_stack");
#		default_methods.push("helpers_path");
#		default_methods.push("_wrapper_options");
#		cms.each do |m|
#		if(default_methods.index(m.to_s)==nil)
#			mn = m.to_s
#			#ManageEngine::APMObjectHolder.instance.log.debug "ManageEngine Monitor Singleton Method : #{s.name} ---> #{m.to_s}"
#			omn = "APMTEST"+mn+"APMTEST"
#			s.instance_eval  %{
#				class << self
#					alias_method :#{omn}, :#{mn}
#				end
#				def self.#{mn} *args, &block
#				begin
#					ActiveSupport::Notifications.instrument("apm.methodstart", {:method=>"#{mn}",:args=>args})
#					res = #{omn} *args, &block
#					ActiveSupport::Notifications.instrument("apm.methodend", {:method=>"#{mn}",:args=>args})
#					return res
#				rescue Exception=>exe
#					puts "Instrument : error in calling class method"
#				raise exe
#				ensure
#				end
#				end
#			}
#		end
#		end#do
#	end#if
#	rescue Exception=>e
#		puts "Exception in instrument : #{e}"
#	ensure
#	end
#end

