require 'agent/am_objectholder'

module ManageEngine
	class APMMetricsStore
		attr_accessor :metrics
		def initialize
			@metrics = Hash.new
		end

		def remove keys
			if keys!=nil
				keys.each {|key| @metrics.delete("#{key}")} 
			end
		end

		def metrics_dup
			@metrics.dup
		end

		def removeData key
#			if @metrics.has_key?(key)
#				val = @metrics[key]
#				val = val.drop(end_indx)
#				@metrics[key]=val
#			end
		  @metrics.delete(key)
		end

	end
end
