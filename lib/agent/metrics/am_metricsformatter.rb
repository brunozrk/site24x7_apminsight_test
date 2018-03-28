require 'agent/am_objectholder'
module ManageEngine
	class APMMetricsFormatter

		def intialize
			@obj = ManageEngine::APMObjectHolder.instance
			@apdex_threshold = 0
		end
		#trans	Vs #[0-rspTime,1-min rt,2-max rt,3-cnt,4-apdx,5-stat,6-toler,7-frustating,8-error_count]
		#DBtrans	Vs #[rspTime,min rt,max rt,cnt,error_count]
		#trace

		def format d
			result = Array.new
			@obj = ManageEngine::APMObjectHolder.instance
			begin
				@apdex_threshold = @obj.config.apdex_t * 1000
				#@obj.log.info "[FORMAT]"
				@transaction = Hash.new
				@db = Hash.new
				@instance = Hash.new
				@dbinstance = Hash.new
				@dboperations = Hash.new
				@keystoremove = Array.new
				d.each do |key,value|
					@keystoremove.push(key)
					updatetransaction value
				end
				updateinstance
				updatedbinstance

				@transaction.each do |key,value|
					res = Hash.new
					res[@obj.constants.mf_namespace] = key
					res[@obj.constants.mf_name] =	@obj.constants.mf_apdex
					valArr= Array.new
					valArr[0] =res
					valArr[1] =value
					result.push(valArr)
				end

				@db.each do |key,value|
					#puts "#{key} == #{value}"
					res = Hash.new
					res[@obj.constants.mf_namespace] = value["tpath"]
					res[@obj.constants.mf_name] = value["path"]
					valArr= Array.new
					valArr[0] =res
					valArr[1] =value["metrics"]
					result.push(valArr)
				end
				@instance.each do |key,value|
					res = Hash.new
					res[@obj.constants.mf_namespace] = ""
					res[@obj.constants.mf_name] = 	@obj.constants.mf_apdex
					valArr= Array.new
					valArr[0] =res
					valArr[1] =value
					result.push(valArr)
				end
				@dbinstance.each do |key,value|
					res = Hash.new
					res[@obj.constants.mf_namespace] = ""
					res[@obj.constants.mf_name] =	@obj.constants.mf_db + @obj.constants.mf_separator + @obj.constants.mf_all + @obj.constants.mf_separator + @obj.constants.mf_all + @obj.constants.mf_separator + @obj.config.app_db # "db/all/all/dummydb"
					valArr= Array.new
					valArr[0] =res
					valArr[1] =value
					result.push(valArr)
				end
				@dboperations.each do |key,value|
					ind = @obj.config.db_operations.index(key)
					if (ind!=nil)	
						res = Hash.new
						res[@obj.constants.mf_namespace] = ""
						res[@obj.constants.mf_name] = @obj.constants.mf_db + @obj.constants.mf_separator + "#{key}" + @obj.constants.mf_separator + @obj.constants.mf_all + @obj.constants.mf_separator + @obj.config.app_db #  "db/"+key+"/all/dummydb"
						valArr= Array.new
						valArr[0] =res
						valArr[1] =value
						result.push(valArr)
					end
				end

				#@obj.log.info "[FORMAT] COMPLETED"
			rescue Exception=>e
				@obj.log.logException "[FORMAT]#{e.message}",e
			end
			@transaction.clear
			@db.clear
			@instance.clear
			result
		end

		def keysToRemove
			@keystoremove
		end

		def updateinstance
			ins_apdx = [0,-1,-1,0,0,0,0,0,0]
			logmetric = Hash.new
			@transaction.each do |key,value|
			  apdexValue = value[0]
			  ins_apdx[0] += apdexValue[0]
				if ins_apdx[1] == -1
				  ins_apdx[1] = apdexValue[1]
				  ins_apdx[2] = apdexValue[2]
				else
  				if(apdexValue[1]<ins_apdx[1])
  				  ins_apdx[1] = apdexValue[1]
          end
          if (apdexValue[2]>ins_apdx[2])
            ins_apdx[2] = apdexValue[2]
          end
				end
				ins_apdx[3] += apdexValue[3]

				ins_apdx[5] += apdexValue[5]	
				ins_apdx[6] += apdexValue[6]	
				ins_apdx[7] += apdexValue[7]	
				ins_apdx[8] += apdexValue[8]
				
				exceptions = value[1][@obj.constants.mf_logmetric]
				if (exceptions != nil)
  				exceptions.each do |name, count|
  				  logmetric[name] = logmetric[name].to_i + count
  				end
				end
			end
			if (ins_apdx[3] > 0)
			  ins_apdx[4] = (ins_apdx[5].to_f + (ins_apdx[6]/2).to_f).to_f/ins_apdx[3].to_f
			  ins_apdx[0] = ins_apdx[0].round(2)
			end
			@instance[":apdex"]=[ins_apdx, {@obj.constants.mf_logmetric=>logmetric}]
		end

		def updatedbinstance
			cnt = 0;
			rt = 0;
			min = -1;
			max = 0;
			error_count = 0;
			if(@db.length>0)
				@db.each do |key,val|
					value = val["metrics"]
					rt = rt + value[0]
					if min == -1
						min = value[1]
						max = value[2]
					end
					if(value[1]<min)
						min = value[1]
					end
					if (value[2]>max)
						max = value[2]
					end
					cnt = cnt  + value[3]
					error_count += value[4]
				end
				@dbinstance[":apdex"]=[rt.round(2),min,max,cnt,error_count]
			end
		end

		def updatetransaction d
			begin
				pl = d["td"]
				dbl = d["db"]
				exc = d["exception"]

				rt = pl["rt"].round(2)
				path = @obj.constants.mf_transaction + @obj.constants.mf_separator + pl["path"]


				apx_stat =  nil
				additionalInfo = nil
				if(@transaction.has_key?(path))
					apx_stat = @transaction[path][0]
					additionalInfo = @transaction[path][1]
				else
					if @transaction.length == @obj.config.metric_overflow_t
					  @obj.log.debug "Metricstore overflow. Current Size: #{@obj.config.metric_overflow_t} #{path}"
					  return
					end
					apx_stat = Array.new
					apx_stat = [0,0,0,0,0,0,0,0,0]
					additionalInfo = Hash.new
				end
				
				if (pl.has_key?("error"))
				  apx_stat[8] += 1
				else
				  apx_stat = apxarray apx_stat,rt
				end
				
				if (exc != nil)
				  logmetric = additionalInfo[@obj.constants.mf_logmetric]
				  if (logmetric == nil)
            additionalInfo[@obj.constants.mf_logmetric] = exc
				  else
            exc.each do |name, count|
              logmetric[name] = logmetric[name].to_i + count
            end
          end
				end
				
				@transaction[path] = [apx_stat, additionalInfo]
				if(dbl!=nil)
					if @db.length < @obj.config.dbmetric_overflow_t
						updatedb dbl,path
					elsif @db.length == @obj.config.dbmetric_overflow_t
						@obj.log.debug "DB metric overflow. Current Size: #{@obj.config.dbmetric_overflow_t} #{path}"
						#@obj.log.info "data = #{@db}"
						of = Hash.new
						stats = Array.new
						stats = [0,0,0,0,0]
						of["tpath"] = @obj.constants.mf_overflow
						#of["tpath"] = @obj.constants.mf_transaction + @obj.constants.mf_separator + @obj.constants.mf_overflow #using this for testing purpose
						of["path"] = @obj.constants.mf_db + @obj.constants.mf_separator + @obj.constants.mf_overflow + @obj.constants.mf_separator + "-" + @obj.constants.mf_separator
						of["metrics"] = stats
						@db[@obj.constants.mf_overflow]=of
						#@obj.log.info "data updated = #{@db}"
					end
				end
			rescue Exception=>e
				@obj.log.info "#{e.message}"
				@obj.log.logException "[Format] [ updatetransaction ] #{e.message}",e
			end
			#	Apmagent::ApmLogger.instance.info "update transaction end"
		end

		# Updates apdex score and increases statisfied, tolerating, frustrated count accordingly
		def apxarray apx_stat,rt 

			#	Apmagent::ApmLogger.instance.info "apxarray : start #{apx_stat}"
			apx_stat = updatert apx_stat,rt 
			if rt <= @apdex_threshold
				apx_stat[5] = apx_stat[5] + 1 
			elsif rt > (4 * @apdex_threshold)
				apx_stat[7] = apx_stat[7] + 1 
			else
				apx_stat[6] = apx_stat[6] + 1 
			end		

			if (apx_stat[3] > 0)
			  apx_stat[4] = (apx_stat[5].to_f + (apx_stat[6].to_f/2).to_f)/apx_stat[3].to_f
			end
			#	Apmagent::ApmLogger.instance.info "apxarray : end #{apx_stat}"
			apx_stat
		end

		# Updates resp time, min rt and max rt in apdex metric
		def updatert apx_stat,rt 
			#	Apmagent::ApmLogger.instance.info "updatert : start"
			apx_stat[3] =  apx_stat[3] + 1
			apx_stat[0] = apx_stat[0] + rt
			if(apx_stat[1] == 0 || rt < apx_stat[1])
				apx_stat[1] = rt
			end
			if(rt > apx_stat[2])
				apx_stat[2] = rt
			end
			#Apmagent::ApmLogger.instance.info "updatert : end"
			apx_stat
		end
		
		#DBtrans	Vs #[rspTime,min rt,max rt,cnt,error_count]
		def updatedb dpl,tpath
			#	Apmagent::ApmLogger.instance.info "updatedb : start"
			dpl.each do |pl|
				rt = pl["rt"].round(2)
				path = pl["sql-strip"]
				dpath = @obj.constants.mf_db + @obj.constants.mf_separator + path
				path = tpath + @obj.constants.mf_separator + dpath
				sql = pl["sql"]
				stat =  nil
				val = nil
				if(@db.has_key?(path))
					val = @db[path]
					stat = val["metrics"]
				else
					val=Hash.new
					val["tpath"] = tpath
          val["path"] = dpath
					stat = Array.new
					stat = [0,rt,rt,0,0]
				end
				if (pl.has_key?("error"))
				  stat[4] += 1
				else
				  stat = updatert stat,rt
				end
				val["metrics"] = stat
				@db[path] = val
				updatedboperations rt, pl["operation"], pl["error"]
			end
			#Apmagent::ApmLogger.instance.info "updatedb : end"
		end

		def updatedboperations rt, operation, isError
			if(@dboperations.has_key?(operation))
				opstats = @dboperations[operation]
			else
			  opstats = Array.new;
				opstats = [0.0,rt,rt,0,0]
			end
			
			if (isError)
			  opstats[4] += 1
			else
  			opstats[0] = opstats[0] + rt
  			if(rt<opstats[1])
  				opstats[1] = rt
  			end
  			if (rt>opstats[2])
  				opstats[2] = rt
  			end
  			opstats[3] = opstats[3] +1
  		end
			@dboperations[operation]=opstats
		end

	end#class
end#module
