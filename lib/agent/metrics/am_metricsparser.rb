require 'agent/am_objectholder'

module ManageEngine
	class APMMetricsParser
		
	  def initialize
			@obj = ManageEngine::APMObjectHolder.instance
		end
		
		# Invoked by APMWorker in dc
		def parse(data)
			@obj = ManageEngine::APMObjectHolder.instance
			parseddata = Hash.new
			begin
				data.each do |txn_name, seqBag|
					@obj.log.debug "[Processing started for - #{txn_name} ]"
					
					seqBag.each do |seqData|
					  begin
            tdata = Hash.new #transaction data -> rt, path,..
            exceptionInfo = Array.new # data to be sent in trace as 'loginfo'
					  
            rootTracker = seqData["roottracker"]
            
					  tdata["td"] = getTransData(rootTracker,tdata)
					  tdata["db"] = getDBData(rootTracker, tdata, exceptionInfo)
            
					  exceptionBag = seqData["exceptions"]
					  if exceptionBag != nil
					    exceptionBag.each do |exceptionRecord|
					      updateExceptionMetric(exceptionRecord.exception,tdata)
					      updateExceptionInfo(exceptionInfo, exceptionRecord.time, exceptionRecord.exception, exceptionRecord.message)
					    end
					  end
					  
					  parseddata = updateParsedData(txn_name, tdata.dup, parseddata)
            
            if @obj.config.trans_trace && (rootTracker.duration >= (@obj.config.trans_trace_t.to_f*1000).to_i || rootTracker.error?)
              parseddata = updateTraceData(rootTracker, parseddata, exceptionInfo)
            end
					  rescue Exception=>e
					    @obj.log.logException "Exception in Parsing txn #{txn_name}",e
					  end
					end # do - seqBag
					
					@obj.store.removeData txn_name
					@obj.log.debug "[Processing END for - #{txn_name} ]"
				end # do-loop
			rescue Exception=>e
				@obj.log.info "Exception : #{e}"
				@obj.log.logException "#{e.message}",e
			end
#			@obj.log.debug "[PARSER] End"
			
			parseddata
		end

		def updateExceptionInfo (exceptionInfo, time, error, message = nil)
      logInfo = { @obj.constants.mf_loginfo_time => time,
                    @obj.constants.mf_loginfo_level => @obj.constants.mf_loginfo_level_warn,
                    @obj.constants.mf_loginfo_str => message != nil ? message : error.message,
                    @obj.constants.mf_loginfo_err_clz => error.class.to_s,
                    @obj.constants.mf_loginfo_st => @obj.util.formatStacktrace(error.backtrace) }
      exceptionInfo.push(logInfo)
		end
		
		def updateParsedData (key, tdata, parseddata)
			begin
				if parseddata.has_key?(key)
					key = rand # Use a random number
				end
				#@obj.log.debug "Update parsed data  : #{key} = > #{tdata}"
				parseddata[key]=tdata
			rescue Exception=>e
				@obj.log.info "Exception in updateParsedData: #{e}"
				@obj.log.logException "#{e.message}",e
			end
				parseddata
		end
		
		# Generates Trace for the transaction and updates it in 'parseddata' hash
		def updateTraceData(rootTracker, parseddata, exceptionInfo)
			if(parseddata.has_key?("trace-data"))
				tData = parseddata["trace-data"];
				if(tData.length == @obj.config.trace_overflow_t)
					trac = getDummyTrace
					tData.push(trac)
					parseddata["trace-data"]=tData
					@obj.log.debug "dummy trace added"
					return parseddata
				elsif tData.length > @obj.config.trace_overflow_t
					@obj.log.debug "trace threshold exceeded. Current Size: #{@obj.config.trace_overflow_t}"
					return parseddata
				end
			end
			begin
			trdata = getTrace(rootTracker)
			trac = updateTrace(rootTracker.url, trdata, exceptionInfo)
			if(parseddata.has_key?("trace-data"))
				traceData = parseddata["trace-data"];
				traceData.push(trac);
				parseddata["trace-data"] = traceData;
			else
				traceData = Array.new
				traceData.push(trac)
				parseddata["trace-data"] = traceData;
			end
			rescue Exception=>e
				@obj.log.info "Exception in updateTraceData: #{e}"
				@obj.log.logException "#{e.message}",e
			end
						parseddata
		end

		def getDummyTrace
			top = Array.new
			path = @obj.constants.mf_overflow
			det = {"thread_name"=>"rorthread","s_time"=>0,"t_name"=>path,"r_time"=>0,"thread_id"=>141}
			trData = Array.new
			trData[0] = 0
			trData[1] = path
			trData[2] = ""
			trData[3] = 0
			trData[4] = 0
			trData[5] = nil
			trData[6] = Array.new
			top[0] = det
			top[1] = trData
			return top
		end

		def getTransData(rootTracker, tdata)
			ret = nil;
			begin
  			if(tdata.has_key?("td"))
  				ret = tdata["td"]
  				ret["rt"] = ret["rt"] + rootTracker.duration
  			else
  				ret = {"rt"=> rootTracker.duration, "path"=>rootTracker.url}
  				if (rootTracker.error?)
  				  ret["error"] = true
  				end
  			end
			rescue Exception=>e
				@obj.log.info "Exception in getTranseData: #{e}"
				@obj.log.logException "#{e.message}",e
			end
			ret
		end

		# Generates DB metric
		def getDBData(tracker, tdata, exceptionInfo)
		  while (tracker != nil)
        tdata["db"] = getDBData(tracker.child, tdata, exceptionInfo)
		    
		    if tracker.kind_of?(ManageEngine::Tracker::DatabaseTracker)
          if tdata["db"] == nil
            tdata["db"] = Array.new
          end
          
          queryInfo = tracker.getQueryInfo
          sqlStrip = queryInfo[0] + "/" + queryInfo[1] + "/dummydb"
    
          ret ={"rt"=>tracker.duration, "sql"=>tracker.getRawQuery,
                "sql-strip"=>sqlStrip, "name"=>tracker.name, "operation"=>queryInfo[0]}
          
          if (tracker.error?)
            ret["error"] = true
          end
          
          tdata["db"].push(ret)
		    end ## DBTracker check
		    
		    if (tracker.error?)
          updateExceptionMetric(tracker.error, tdata) # <= previously it was 'ret'
          updateExceptionInfo(exceptionInfo, tracker.endtime.to_i, tracker.error)
		    end
		    
		    tracker = tracker.sibling
		  end ## while loop
		  
		  tdata["db"]
		end

		def updateExceptionMetric (exception, tdata)
		  excData = tdata["exception"]
		  if (excData == nil)
		    excData = Hash.new
		    tdata["exception"] = excData
		  end
		  
		  excData[exception.class.to_s] = excData[exception.class.to_s].to_i + 1
		  excData[@obj.constants.mf_logmetric_warning] = excData[@obj.constants.mf_logmetric_warning].to_i + 1
		end
		
		def updateTrace(url, trans, exceptionInfo)
#			{"thread_name":"http-8080-6","s_time":1326276180289,"t_name":"transaction\/http\/Test-App\/login","r_time":18,"thread_id":141}
			top =  Array.new
			path = @obj.constants.mf_transaction + @obj.constants.mf_separator + url
			det = {"thread_name"=>"rorthread","s_time"=>trans[0],"t_name"=>path,"r_time"=>trans[3],"thread_id"=>141}
			
			exception = trans[5] != nil ? trans[5][@obj.constants.mf_exception_st] : nil
			if (exception != nil)
			  det[@obj.constants.mf_err_st] = exception
			end
			
			if (exceptionInfo.length > 0)
			  det[@obj.constants.mf_loginfo] = exceptionInfo
			end
			
			top[0] = det
			top[1] = trans
			top
		end
		
		def getTrace(rootTracker)
		  trace = Array.new
		  traceDetails(rootTracker, trace)
		  
		  return trace[0]
		end

		def traceDetails tracker, traceArr
		  
		  siblingDuration = 0
		  
		  while tracker != nil
		    
		    childTrace = Array.new
		    childDuration = traceDetails tracker.child, childTrace
		    
		    traceItem = Array.new
		    traceItem[0] = tracker.starttime
		    if tracker.kind_of?(ManageEngine::Tracker::DatabaseTracker)
          queryInfo = tracker.getQueryInfo
          traceItem[1] = queryInfo[0] + " - " + queryInfo[1]
        else
          traceItem[1] = tracker.name
		    end
		    traceItem[2] = ""
		    traceItem[3] = tracker.duration
        traceItem[4] = tracker.duration - childDuration
        traceItem[5] = tracker.getAdditionalInfo
		    traceItem[6] = childTrace.empty? ? nil : childTrace
		    
		    traceArr.push(traceItem)
		    
		    siblingDuration += tracker.duration
		    
		    tracker = tracker.sibling
		  end
		  
		  return siblingDuration
		end


		def updateExclusiveTrace data
			childs = data[6]
			childs.each do |arr|
				data[4] = data[4] - (updateExclusiveTrace arr)[3]
			end
			data
		end


	end
end
