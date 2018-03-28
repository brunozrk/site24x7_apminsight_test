require "agent/am_objectholder"
require "agent/server/worker/am_worker"
require "agent/server/instrument/environment"

require 'socket'

module ManageEngine
	class APMAgent
		def initialize
			@obj = ManageEngine::APMObjectHolder.instance
			@obj.log.debug "Agent Initialization - START"
			doConnect

			if !@obj.shutdown && @obj.agent_initialized
				@obj.log.info "Agent Initialization - DONE"
				ManageEngine::Environment.new.detect_and_instrument
				
				doDispatcherActions
				doCollect
				puts "APM Insight Ruby Agent Started"
			else
				@obj.log.info "Agent Initialization Failed - Going to shutdown"
				#While parsing the response from /arh/connect we set instrumenter to nil on delete request
				#Server startup fails when the below instruction is executed
				#@obj.instrumenter.doUnSubscribe
				@obj.shutdownagent
			end
           	

       end

		def doConnect
			begin	
				if @obj.shutdown
					@obj.log.info "[ Problem in Agent Startup ]"
				else
					agentInfo = @obj.config.getAgentInfo
					resp = nil
					if @obj.config.alreadyconnected
						@obj.log.debug "[doConnect] Already Connected - Make Contact - Instance id = #{@obj.config.instance_id}"
						if @obj.config.site24x7
							resp = startConnect "?license.key="+@obj.config.license_key+"&instance_id="+@obj.config.instance_id,agentInfo
						else
							resp = startConnect "?instance_id="+@obj.config.instance_id,agentInfo
						end
					else
						@obj.log.debug "[doConnect] Going to connect - New "
						if @obj.config.site24x7
							resp = startConnect "?license.key="+@obj.config.license_key,agentInfo
						else
							resp = startConnect "",agentInfo
						end
					end
					
					if (resp == nil || !resp.has_key?("instance-info"))
					  @obj.log.info "[doConnect] [ Problem in connecting server] [ Going to shutdown ]"
            @obj.shutdown=true
					else
						aData = resp["instance-info"]
						aData["agent.id"]=aData.delete("instanceid")
						aData["agent.enabled"]=true
						@obj.config.updateAgentInfoFile(aData)
						@obj.log.info "[doConnect] Agent successfully connected - InstanceID  : #{@obj.config.instance_id}"
					end

					if(!@obj.shutdown)
						@obj.agent_initialized=true
					end
				end
			rescue Exception=>e
				@obj.shutdown = true
				@obj.log.logException "[doConnect] Exception while connecting server. [ Going to shutdown ] ",e
			end
		end


		def doCollect
			@obj.log.info "[doCollect] Starts - Wait time : #{@obj.config.connect_interval} seconds "
			begin
				ManageEngine::APMWorker.getInstance.start
			rescue Exception=>e
				@obj.log.logException "[doCollect]  Exception during worker  startup  #{e.message}",e
				@obj.shutdown=true
			end
		end


		def startConnect uri,data
			resp = @obj.connector.post @obj.constants.connect_uri+uri,data
		end

		def doDispatcherActions
		  @obj.log.info "Dispatcher: #{@obj.config.app_dispatcher}"
			case @obj.config.app_dispatcher
				when 'passenger'
					#starting a new process
      				PhusionPassenger.on_event(:starting_worker_process) do |forked|
        				if forked
                			@obj.log.info "starting_worker_process : Process ID :#{Process.pid} : Creating new apm worker"
                			doCollect
        				else
                			doCollect
		                	@obj.log.info "starting_worker_process : Conservative Process ID :#{Process.pid} - No new worker"
        				end
     			 	end
      				# shutting down a process.
				    PhusionPassenger.on_event(:stopping_worker_process) do
                		ManageEngine::APMWorker.getInstance.stop
                		@obj.log.info "stopping_worker_process :Process ID :#{Process.pid} ---->  #$$ "
     				end
     		when 'unicorn'
     		   Unicorn::HttpServer.class_eval do
     		     old_object = instance_method(:worker_loop)
     		     define_method(:worker_loop) do |worker|
               ::ManageEngine::APMObjectHolder.instance.agent.doCollect
     		       old_object.bind(self).call(worker)
     		     end
     		   end
				else#case

				end#case
		end
	end#c
end#m

