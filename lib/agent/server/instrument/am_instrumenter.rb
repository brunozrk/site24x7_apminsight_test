##
##  This is Rails framework specific tracking mechanism, they are moved to multiple files for separate tracking
##

#require 'agent/am_objectholder'
#require 'socket'
#module ManageEngine
#	class APMInstrumenter
#	@t =nil;
#	def initialize
#		@obj=ManageEngine::APMObjectHolder.instance
#	end
#
#	def doSubscribe
#		@obj=ManageEngine::APMObjectHolder.instance
#		@obj.log.debug "[ instrumenter ] [ Subscriber for Agent ]"
#		@subscriber = ActiveSupport::Notifications.subscribe  do |name, start, finish, id, payload|
#		if(ManageEngine::APMObjectHolder.instance.config.agent_enabled)
#			#rt = (finish-start).to_i
#			 ManageEngine::APMWorker.getInstance.start
#			ManageEngine::APMObjectHolder.instance.log.debug "[ Notifications for Agent ] #{Thread.current} #{id} #{name} - #{payload[:path]}"
#			#trace= caller;
#			#puts ">>> Threadlocal var : #{Thread.current[:apminsight]}"
#			if name=="sql.active_record"
#			  #Thread.current[:apminsight] = "#{Thread.current[:apminsight]} + #{payload[:sql]}"
#			  if payload[:name] != "SCHEMA"
#          @obj.log.debug ">>>>>>>> SQL: #{payload[:sql]}"
#			  end
#			  @obj.log.debug "~~~~~ SQL Payload: #{payload}"
#			end
#			id = "#{Thread.current}"
#			stats = Hash.new
#			stats["name"] = name;
#			stats["start"] = start.to_f * 1000;
#			stats["end"] = finish.to_f * 1000;
#			stats["id"] = id;
#			stats["payload"] = payload;
#			if (name=="sql.active_record" && (finish.to_f - start.to_f)>=(ManageEngine::APMObjectHolder.instance.config.sql_trace_t).to_f)
#				stats["trace"] = caller(20); # Taking stacktrace of depth 20
#			end
#			stats["ctime"] =ManageEngine::APMObjectHolder.instance.util.currenttimemillis;
#			ManageEngine::APMObjectHolder.instance.collector.updateTransaction(id,stats);
#		else
#			ActiveSupport::Notifications.unsubscribe @subscriber
#				@obj.log.info "[ instrumenter ] [ RETURNING NO METRICS] "
#		end
#		end
#	end
#
#	def doUnSubscribe
#		ActiveSupport::Notifications.unsubscribe @subscriber
#	end
#
#end #class
#end#module
