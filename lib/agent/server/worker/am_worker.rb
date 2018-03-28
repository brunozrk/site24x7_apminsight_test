require 'json'
require 'thread'

module ManageEngine
class APMWorker
	@work =nil;
	@status = 'not_init'
	@id = 0
	attr_accessor :id
    def initialize
      @status = "initialized"
      @id = Process.pid
    end

    def start
      @obj = ManageEngine::APMObjectHolder.instance
    
    	if @status=="working"
        @obj.log.debug "woker thread already started"
      elsif @status == "initialized"
        @obj.log.info "start worker thread for - #{Process.pid} :: #{@status}  "
        #@obj.log.info "Starting APMWorker Thread #{Process.pid} "
        @apm = Thread.new do
          @status  = 'working'
      	  while !@obj.shutdown do
      	    checkforagentstatus
    				updateConfig
            dc
    				sleep (@obj.config.connect_interval).to_i
          end#w
          @status= "end"
          @obj.log.debug "Worker thread ends"
        end
      end
    end
    
    def self.getInstance
      if(@work==nil || @work.id!=Process.pid)
       	@work = ManageEngine::APMWorker.new
      end
      return @work
    end

		def updateConfig
			if(@obj.config.lastupdatedtime!=File.mtime(@obj.constants.apm_conf).to_i)
				@obj.log.info "Configuration File Changed... So Updating Configuration."
				agent_config_data = @obj.config.getAgentConfigData
				@obj.config.lastupdatedtime=File.mtime(@obj.constants.apm_conf).to_i
				@obj.config.configureFile
				@obj.config.assignConfig
				new_agent_config_data = @obj.config.getAgentConfigData
				sendUpdate = "false"
				agent_config_data.each do|key,value|
					if key != "last.modified.time"
						newValue = new_agent_config_data[key]
						if value != newValue
							sendUpdate = "true"
						end
					end
				end
				if sendUpdate == "true"
					@obj.log.info "sending update to server #{new_agent_config_data}"
					data1 =  Hash.new
					data1["custom_config_info"]=new_agent_config_data
 	       			        resp = @obj.connector.post @obj.constants.connect_config_update_uri+@obj.config.instance_id,data1
				end
			end
		end
		
		def checkforagentstatus
			prevState = @obj.config.agent_enabled
			@obj.config.checkAgentInfo
			if !@obj.config.agent_enabled
				@obj.log.info "Agent in Disabled State."
				if prevState
					@obj.log.info "Agent in Disabled State. Going to unsubscribe"
#					@obj.instrumenter.doUnSubscribe
				end
			else
				if !prevState
					@obj.log.info "Agent in Active State."
#					@obj.instrumenter.doSubscribe
				end
			end
		end

        def stop
            dc
			@obj.shutdown = true;
        end

        def dc
    	    begin
                @obj.log.debug "[dc] collecting..."
                now = @obj.util.currenttimemillis
                result =  Array.new
                result.push(@obj.last_dispatch_time)
                                result.push(now)
                data = Array.new
                trd= nil;
                @last_dispatch_time = now
                if @obj.config.agent_enabled
                        d = @obj.parser.parse @obj.store.metrics_dup
                        if(d!=nil && d.has_key?("trace-data"))
                                trd = d.delete("trace-data");
                                #@obj.log.info "[dc] [TRACE] : #{d}"
                        end
                        #@obj.log.info "[dc] Data - #{d}"
                        if(d.length>0)
                                data =@obj.formatter.format d
                                #@obj.log.debug "[dc] Formatted Data - #{data}"
                        end
                        @obj.store.remove @obj.formatter.keysToRemove
                end #if
                fd = Array.new
                fd.push(data)
                if(trd!=nil)
                	fd.push(trd)
                end
				@obj.log.debug "[dc] data to store : #{fd}"
                send_save fd
				@obj.log.debug "[dc] collecting ends"
	        rescue Exception=>e
                @obj.log.logException "[dc]  Exception during data Collection. #{e.message}",e
                @obj.shutdown=true
    	    end
		end

        def senddata d
               # @obj.log.info("Send data --- #{d}")
                result =  Array.new
                result.push( (File.mtime(@obj.constants.agent_lock).to_f*1000).to_i)
                now = @obj.util.currenttimemillis
                result.push(now)
                write @obj.constants.agent_lock ,"#{Process.pid}"
                data  = read @obj.constants.agent_store
                data.push(d);
                tdata = Array.new;
                trdata = Array.new;
                data.each do |val|
                        case val.size
                        when 1
                                tdata.concat(val[0])
                        when 2
                                tdata.concat(val[0])
                                if (trdata.size < @obj.config.trace_overflow_t)
                                  trdata.concat(val[1])
                                end
                        end
                end
                result.push(merge(tdata))
                resp = @obj.connector.post @obj.constants.connect_data_uri+@obj.config.instance_id,result
                @obj.log.info "#{tdata.size} metric(s) dispatched."
                if trdata.size>0
                        result[2]=trdata;
                        resp = @obj.connector.post @obj.constants.connect_trace_uri+@obj.config.instance_id,result
                        @obj.log.info "#{trdata.size} trace(s) dispatched."
                end
        end

        def save fd
                begin
                	data = fd.to_json;
                	write @obj.constants.agent_store,data
                rescue Exception=>e
                	@obj.log.logException "[dc]  Exception during save. #{e.message}",e
                end
        end

        def send_save data
                begin
                	if FileTest.exist?(@obj.constants.agent_lock)
                        if Time.now.to_i - File.mtime(@obj.constants.agent_lock).to_i >= (@obj.config.connect_interval).to_i
                                @obj.log.debug "worker send signal"
                                senddata data
                        else
                                @obj.log.info "worker save signal"
                                save data
                        end
                else
                        @obj.log.info "worker save signals"
                        save data
                        write @obj.constants.agent_lock,"#{Process.pid}"
                end
                rescue Exception=>e
                        @obj.log.logException "Exception in decision making send or save #{e.message}",e
                end
        end

		def read p
            data = Array.new
	        File.open( p, "r+" ) { |f|
			    f.flock(File::LOCK_EX)
            	begin
               		f.each_line do |line|
               		   begin
               		     data.push(JSON.parse(line))
               		   rescue Exception=>ex
               		     @obj.log.logException "Error Parsing data, Skipping line #{line}", ex
               		   end
              		end
			       f.truncate 0
          		rescue Exception=>e
                	@obj.log.logException "Exception while reading data #{e}",e
         		ensure
                	f.flock(File::LOCK_UN)
        		end
        	}
            data
       end


        def write (p,  data )
            File.open( p, "a+" ) { |f|
             	f.flock(File::LOCK_EX)
                begin
					f.write "#{data}\n"
                rescue Exception=>e
                        @obj.log.logException "Exception while writing data #{e.message}",e
		        ensure
                    f.flock(File::LOCK_UN)
                end
            }
        end

		def merge data
#                 @obj.log.info "BEFORE MERGE : #{data}"
			tdata =Hash.new ;
			data.each do |sd|
				name= sd[0]["ns"] + sd[0]["name"];
				if tdata.has_key?(name)
					if (sd[0]["name"]=="apdex")
						tdata[name][1] = mapdx(tdata[name][1],sd[1])
					else
						tdata[name][1] = mapdb(tdata[name][1],sd[1])
					end
				else
					tdata[name]=sd;
				end
			end
#@obj.log.info "MERGED DATA : #{tdata}"
			res = Array.new;
			tdata.each do|key,value|
				res.push(value);
		   end
		res
	end


		def mapdx res,dat
		  begin
  		  rtData = res[0];
  			rtData[0] = rtData[0]+dat[0][0];
  			if dat[0][1]<rtData[1]
  			  rtData[1]=dat[0][1]
  			end
  			if dat[0][2]>rtData[2]
  			  rtData[2]=dat[0][2]
  			end
  			rtData[3] = rtData[3]+dat[0][3]
  			rtData[5] = rtData[5]+dat[0][5]
  			rtData[6] = rtData[6]+dat[0][6]
  			rtData[7] = rtData[7]+dat[0][7]
  			rtData[4] = rtData[3] != 0 ? (rtData[5].to_f + (rtData[6].to_f/2).to_f).to_f/rtData[3].to_f : 0
  			res[0] = rtData
  			
  			resExcepData = res[1][@obj.constants.mf_logmetric]
  			excepData = dat[1][@obj.constants.mf_logmetric]
  			if (resExcepData == nil)
  			    resExcepData = excepData
  			else
  			  if (excepData != nil)
  			    resExcepData = resExcepData.merge(excepData){|key, oldval, newval| newval + oldval}
  			  end
  			end
  			
  			res[1][@obj.constants.mf_logmetric] = resExcepData != nil ? resExcepData : Hash.new
  			rescue Exception=>e
  			  @obj.log.logException "Exception while merging data",e
  			end
			res
		end

		def mapdb res,dat
			res[0] = res[0]+dat[0];
				if dat[1]<res[1]
				res[1]=dat[1]
			end
			if dat[2]>res[2]
				res[2]=dat[2]
			end
			res[3] = res[3]+dat[3]
			res[4] = res[4]+dat[4]
			res
		end
	
end#c
end#m
