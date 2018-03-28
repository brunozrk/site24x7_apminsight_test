
require "agent/configuration/am_configuration"
require "agent/logging/am_logger"
require "agent/util/am_util"
require "agent/util/am_constants"
require "agent/server/am_connector"
require "agent/server/am_agent"
require "agent/metrics/am_metricscollector"
require "agent/metrics/am_metricstore"
require "agent/metrics/am_metricsformatter"
require "agent/metrics/am_metricsparser"
require "agent/util/transaction_util"

module ManageEngine

	class APMObjectHolder
		attr_reader :config,:log,:util,:constants,:shutdown,:connector,:agent,:collector, :txn_util
		attr_accessor :shutdown,:agent_initialized,:last_dispatch_time,:store,:formatter,:parser
		@@objects = nil
		#Don't Change the Order of Initialize
		def initializeObjects
			@agent_initialized	=		false
			@shutdown 			=		false
			@constants 			= 		ManageEngine::APMConstants.new
			@log 				= 		ManageEngine::APMLogger.new
			@util 				=		ManageEngine::APMUtil.new
			@util.setLogger @log
			@config 			= 		ManageEngine::APMConfig.new
			@connector 			= 		ManageEngine::APMConnector.new
			@store 				=	 	ManageEngine::APMMetricsStore.new
			@collector			=		ManageEngine::APMMetricsCollector.new
      @txn_util = ManageEngine::TransactionUtil.new
			@formatter 			= 		ManageEngine::APMMetricsFormatter.new
			@parser 			= 		ManageEngine::APMMetricsParser.new
			@agent 				= 		ManageEngine::APMAgent.new
			@last_dispatch_time	=		@@objects.util.currenttimemillis
			@@objects.log.debug "[APMObjectHolder] [ All Objects Initialized ] "
		end

  		def self.instance
			if(@@objects==nil)
				@@objects = ManageEngine::APMObjectHolder.new
				@@objects.initializeObjects
			end
    		return @@objects
  		end

		def shutdownagent
			###@agent_initialized=false
			#@shutdown = true
			#@constants = nil
			#@util = nil
			#@config = nil
			#@connector = nil
			#@store = nil
			#@collector=nil
			#@instrumenter = nil
			#@formatter = nil
			#@parser = nil
			#@agent = nil
			#@log.info "[ APMObjectHolder ][ All Objects deleted ] "
			#@log = nil
		end

	end #c
end#m
