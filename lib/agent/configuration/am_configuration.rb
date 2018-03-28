require 'rubygems'
require 'json'
require 'socket'
require 'net/http'
require 'agent/am_objectholder'
require 'version'

module ManageEngine
	class APMConfig
		attr_reader :agenthost,:agentport,:instance_id,:alreadyconnected,:apmhost,:apmport,:license_key,:site24x7, :site24x7url, :hostType
		attr_reader :appname,:proxyneeded, :apdex_t, :trans_trace, :trans_trace_t, :sql_capture, :sql_capture_params, :sql_trace_t,:proxy_user,:proxy_pass, :metric_overflow_t, :trace_overflow_t, :dbmetric_overflow_t
		attr_reader :proxy_host,:proxy_port ,:is_secured, :logs_dir ,:connection_retry,:agent_enabled,:connect_interval,:db_operations,:txn_skip_listen, :url_merge_pattern
		attr_accessor :app_db,:app_dispatcher,:lastupdatedtime
		def initialize
			@obj = ManageEngine::APMObjectHolder.instance
			
    		#@config = @obj.util.readProperties(@obj.constants.apm_conf)
			configureFile
			@agenthost = Socket.gethostname
			assignConfig
			@obj.log.setLevel @config["apminsight.log.level"]
			@instance_id  = 0
			@agent_enabled = false
			@alreadyconnected = checkAgentInfo
			@site24x7 = checkLicenseFile
			if (@site24x7)
			  @site24x7url = @license_key.start_with?('eu') ? @obj.constants.site24x7EUurl : @obj.constants.site24x7USurl
			end
			@db_operations =["select","insert","update","delete"]
			urlMergePattern
			@hostType = getHostType
			@obj.log.info "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
			@obj.log.info "APP HOME #{File.absolute_path(".")} "
			@obj.log.info "APP HOME #{Dir.pwd} "
			@obj.log.info "Agent Version : #{ManageEngine::APMInsight::VERSION}"
			@obj.log.info "Configuration : "
			@obj.log.info "Hostname : #{@agenthost}"
			@obj.log.info "Host Type: #{@hostType}"
			@obj.log.info "Agent Already Connected : #{@alreadyconnected}"
			@obj.log.info "Agent Enabled : #{@agent_enabled}"
			@obj.log.info "Allowed DB Operations : #{@db_operations}"
			@config.each do|key,val|
			@obj.log.info "#{key} => #{val}"
				end
			@obj.log.info "URL Merge Patterns"
			@url_merge_pattern.each do |key, val|
				@obj.log.info "#{key} => #{val}"
			end
			@obj.log.info "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
			@app_db="dummydb"
			@app_dispatcher = getDispatcher
			@lastupdatedtime=File.mtime(@obj.constants.apm_conf).to_i
 		end
		
		def configureFile
			begin
				if(FileTest.exists?(@obj.constants.apm_conf))
					#conf file exists in APPlication Home
						@obj.log.debug "Config File Exists. It is read from #{@obj.constants.apm_conf}"
					@config = @obj.util.readProperties(@obj.constants.apm_conf)
				else
				  gemSpecs = Gem.loaded_specs[@obj.constants.s247_apm_gem]
				  if (gemSpecs == nil)
				    gemSpecs = Gem.loaded_specs[@obj.constants.apm_gem]
				  end
					gem_conf = gemSpecs.full_gem_path
					#gem_conf = File.join(gem_conf, 'lib')
					gem_conf = File.join(gem_conf, 'conf')
					gem_conf = File.join(gem_conf, 'apminsight.conf')
					#conf file not exists in APPlications Home. So 1. copy it for gem locations
					if @obj.util.copyFiles gem_conf,@obj.constants.apm_conf
						#copied sucessfully
						@obj.log.info "Config File copied to application home directory. It is read from #{@obj.constants.apm_conf}"
						@config = @obj.util.readProperties(@obj.constants.apm_conf)
					else
						#Problem in copying, so reading props from Conf file in Gem Location
						@obj.log.warn "Config File not copied. It is read from #{gem_conf}"
						@config = @obj.util.readProperties(gem_conf)
					end
				end
				
			rescue Exception=>e
				@obj.log.info "[Exception] Problem in Reading Configuration File : \n File : #{@obj.constants.apm_conf}"
				@obj.log.logException "#{e.message}",e
				@config = @obj.util.readProperties(gem_conf)
			ensure
			end
		end

		def checkAgentInfo
			if FileTest.exists?(@obj.constants.agent_conf)
				@obj.log.debug "Status : Agent Already Connected"
				props = @obj.util.readProperties(@obj.constants.agent_conf)
				instance_id = props["agent.id"]
				
				if (instance_id == nil || instance_id == "")
				  # If instance id is not found or empty, it means the apminsight.info is being modified by user
				  # Ignore all its entry
				  @obj.log.warn "File: #{@obj.constants.agent_conf} is corrupted. Agent will continue ignoring these values."
				  return false
				else
				  @instance_id = instance_id
				end
				
				@agent_enabled= @obj.util.getBooleanValue props["agent.enabled"]
				true
			else
				@obj.log.info "Status : Agent not connected"
				false
			end
		end

		def checkLicenseFile
			if(@license_key != nil)
				@obj.log.info "License key is not null. Connecting to site24x7"
				@obj.constants.setLicenseKey @license_key
				true
			else
				@obj.log.info "License key is null. Connecting to APPManager"
				false
			end

		end
		
		def urlMergePattern
			@url_merge_pattern = Hash.new
			begin
				if (FileTest.exists?(@obj.constants.mergepattern_conf))
					@url_merge_pattern=@obj.util.readProperties(@obj.constants.mergepattern_conf)
				end
			rescue Exception => e
				@obj.log.info "[Exception] Problem in Reading Configuration File : \n File : #{@obj.constants.mergepattern_conf}"
				@obj.log.logException "#{e.message}",e
			end
		end

		def updateAgentInfoFile(props)
			@instance_id = props["agent.id"]
			@agent_enabled= @obj.util.getBooleanValue props["agent.enabled"]
			@obj.util.writeProperties(@obj.constants.agent_conf,props)
		end

		def initValues
			@apmport=8080
			@appname="My Application"
			@proxyneeded = false
			@proxy_host="localhost"
			@proxy_port=80
			@proxy_user=""
			@proxy_pass=""
			@is_secured=false
			@logs_dir="./log"
			@connection_retry = 0
			@connect_interval = 60
			@apdex_t=0.5
			@txn_skip_listen=Array.new
			@trans_trace_t=2
			@sql_trace_t=3
			@metric_overflow_t=250
      @dbmetric_overflow_t=500
			@trace_overflow_t=30
			@site24x7url = @obj.constants.site24x7USurl #default agent communication URL
		end

		def assignConfig
		initValues
		 @config.each do |key,value|
		 	 value = checkAndGetEnvValue(value)
			 case key
			 when "application.name" then @appname=value
			                              if (ENV.has_key?('APM_APPLICATION_NAME'))
			                                @appname = ENV['APM_APPLICATION_NAME']
			                              end
			 when "apm.host" then @apmhost=value
			 when "apm.port" then @apmport=isInteger(@apmport,value)
			 when "license.key" then @license_key=value
			                         if (@license_key.empty? && ENV.has_key?('S247_LICENSE_KEY'))
			                           @license_key = ENV['S247_LICENSE_KEY']
			                         end
			 when "behind.proxy" then @proxyneeded=@obj.util.getBooleanValue value
			 when "agent.server.port" then @agentport=isInteger(@agentport,value)
			 when "apdex.threshold" then @apdex_t=isFloat(@apdex_t,value)
			 when "transaction.trace.enabled" then @trans_trace=@obj.util.getBooleanValue value
			 when "transaction.trace.threshold" then @trans_trace_t=isFloat(@trans_trace_t,value)
			 when "sql.capture.enabled" then @sql_capture=@obj.util.getBooleanValue value
			 when "transaction.trace.sql.parametrize" then @sql_capture_params=@obj.util.getBooleanValue value
			 when "transaction.trace.sql.stacktrace.threshold" then @sql_trace_t=isFloat(@sql_trace_t,value)
			 when "proxy.server.host" then @proxy_host=value
			 when "proxy.server.port" then @proxy_port=isInteger(@proxy_port,value)
			 when "proxy.auth.username" then @proxy_user=value
			 when "proxy.auth.password" then @proxy_pass=value
			 when "apm.protocol.https" then @is_secured=@obj.util.getBooleanValue value
			 when "apminsight.log.dir" then @logs_dir=value
			 when "apminsight.log.level" then @obj.log.setLevel value
			 when "agent.connection.retry" then @connection_retry=value #Not in Conf - yet to come
			 when "agent.polling.interval" then	 @connect_interval=isInteger(@connect_interval, value)#Not in Conf - yet to come
			 when "transaction.skip.listening" then @txn_skip_listen=@obj.util.getArray value.gsub("\s", ""),","
			 when "metricstore.metric.bucket.size" then @metric_overflow_t = isInteger(@metric_overflow_t, value)
       when "metricstore.dbmetric.bucket.size" then @dbmetric_overflow_t = isInteger(@dbmetric_overflow_t, value)
       when "transaction.tracestore.size" then @trace_overflow_t = isInteger(@trace_overflow_t, value)
			end
		 end
		end
		
		#Checks whether the given value is Environment Variable
		def checkAndGetEnvValue(data)
		  begin
  			value = "#{data}"[/{(.*)}/,1]
  			if (value != nil && ENV.has_key?(value))
  				return data.gsub(/{.*}/, ENV[value])
			  end
			rescue Exception=>e
			end
			return data
		end

		def getHostType
		  begin
  		  # Check for AWS environment
  		  response = Net::HTTP.get_response(URI('http://169.254.169.254/latest/meta-data/'))
  		  if (response.kind_of? Net::HTTPOK)
  		    @hostType = "AWS"
  		    return @hostType
  		  end
      rescue Exception => e
      end
      
      begin
  		  #Check for Azure environment
        response = Net::HTTP.get_response(URI('http://169.254.169.254/metadata/v1/maintenance'))
        if (response.kind_of? Net::HTTPOK)
          @hostType = "AZURE"
          return @hostType
        end
		  rescue Exception => e
		  end
		  
      @hostType = nil
		end
		
		def getAgentInfo
			data =  Hash.new
			agentdata = Hash.new
			agentdata = {"application.type"=>"RUBY","application.name"=>@appname,"hostname"=>@agenthost,"port"=>@agentport,"agent.version"=>ManageEngine::APMInsight::MAJOR_VERSION}
		  if (@hostType != nil)
		    agentdata["host.type"]=@hostType
		  end
			data["agent_info"]=agentdata
			data["environment"]=getEnvData
			data["custom_config_info"]=getAgentConfigData
			data
		end

		def getEnvData
			env =  Hash.new
			begin
			ENV.to_hash.each do |key, value|
				env[key] = value
			end
			#env["Application Path"]="#{Rails.root}"
			rescue Exception=>e
			end
			env
		end
			
		def getAgentConfigData
			agentconfig = Hash.new
			agentconfig["last.modified.time"]=@lastupdatedtime*1000
			agentconfig["apdex.threshold"]=@apdex_t
			agentconfig["sql.capture.enabled"]=0
			if @sql_capture
				agentconfig["sql.capture.enabled"]=1
			end
			agentconfig["transaction.trace.enabled"]=0
			if @trans_trace
				agentconfig["transaction.trace.enabled"]=1
			end
			agentconfig["transaction.trace.threshold"]=@trans_trace_t
			agentconfig["transaction.trace.sql.parametrize"]=0
			if @sql_capture_params
				agentconfig["transaction.trace.sql.parametrize"]=1
			end
			agentconfig["transaction.trace.sql.stacktrace.threshold"]=@sql_trace_t
			agentconfig["transaction.tracking.request.interval"]=1
			agentconfig
		end

		def getDispatcher
		dispatcher = "unknown"
		if defined?(PhusionPassenger) then
			dispatcher = "passenger"
		end
		if defined?(::Unicorn) && defined?(::Unicorn::HttpServer) then
		  dispatcher = "unicorn"
		end
		dispatcher
		end
		
		def isInteger default,value
			if @obj.util.is_integer value
				value.to_i
			else
				@obj.log.info "Problem in getting Integer Value #{value} .. So setting default value #{default} "
				default.to_i
			end

		end

		def isFloat default,value
			if @obj.util.is_float value
				value.to_f
			else
				default.to_f
				@obj.log.info "Problem in getting Integer Value #{value} .. So setting default value #{default} "
			end
		end

		def update_config configInfo
			filepath = @obj.constants.apm_conf
			f = "apminsight.conf.new"
			begin
				propsFile=File.open(filepath, 'r')
				file = File.new(f,"w+")
	      			propsFile.read.each_line do |line|
        			line.strip!
        			if (line[0] != ?# and line[0] != ?=)
          				i = line.index('=')
        	  			if (i)
						key1 = line[0..i - 1].strip
						if configInfo.has_key?(key1)
							file.puts "#{key1}=#{configInfo[key1]}\n"
						else
							file.puts "#{line}\n"
						end
	          			else
						file.puts "#{line}\n"
         				end
				else
					file.puts "#{line}\n"
        			end
      	  		end
			rescue Exception=>e
				@obj.log.info "Problem in Reading / Writing Property File :  #{e.message} "
				@obj.log.error "#{e.backtrace}"
			ensure
					propsFile.close
					file.close
			end
			res = @obj.util.copyFiles f, filepath
			if res
				@obj.log.info "copyFiles result = #{res}"
				#delete apminsight.conf.new has to be done
			end
			configureFile
			assignConfig
		end


	end#c
end#m

