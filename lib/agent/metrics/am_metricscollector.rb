require 'agent/am_objectholder'


module ManageEngine
	class APMMetricsCollector
		def initialize
			@obj = ManageEngine::APMObjectHolder.instance
		end

		def getTransactions
			@obj.store.metrics_dup
		end

		def updateTransaction( id ,values)
			if(@obj.store.metrics.has_key?(id))
				temp = @obj.store.metrics[id]
				temp.push(values);
			else
				temp = Array.new
				temp.push(values);
				@obj.store.metrics[id]=temp
			end				
		end

		def transactionmetricskeys
			@obj.store.keys
		end

	end#class
end#module
