require 'net/http'
require 'net/https'
require 'uri'
require 'json'
#require "agent/server/instrument/am_instrumenter"

module ManageEngine
	class APMConnector

		def initialize 
			@obj = ManageEngine::APMObjectHolder.instance
			@pretry =0
			@gretry =0
		end

		def post uri,data
			@pretry = @pretry +1
			begin

				u = url uri
				#@obj.log.info "[connector] [ POST]  START"
				@obj.log.debug "[connector] [ POST]  : \n\n#{u}\n\n#{data}\n\n"
				con =  connection(u)
				req = Net::HTTP::Post.new(u.request_uri,initheader = {'Content-Type' =>'application/json'})
				req.body=data.to_json
				resp = con.request(req)
				@obj.log.debug "[connector] [POST ] \n Response : #{resp} \nResponse Code : #{resp.code}\nMessage : #{resp.message}\nBody : #{resp.body}"
				rdata = responseParser resp
				@pretry = 0
				#@obj.log.info "[connector] [ POST]  END"
				return rdata
			rescue Exception=>e
				@obj.log.logException "[connector] Exception while connecting server- Data not sent \n",e
				if @pretry >=@obj.config.connection_retry
					#@obj.shutdown= true
					return nil
				else
					@obj.log.info "[connector] Exception found in Post request - Retrying - Count - #{@pretry}"
					return post uri,data
				end

			end
			@pretry = 0
		end

		def get uri
			@gretry = @gretry +1
			begin
				u = url uri
				#@obj.log.info "[connector] [ GET ]  START"
				@obj.log.debug "[connector] [ GET]  : \n#{u}\n"
				req = Net::HTTP::Get.new(u.request_uri)
				resp = con.request(req)
				#@obj.log.info "[connector] [ GET ]  END"
			rescue Exception=>e
				@obj.log.logException "[connector] [ GET]  Exception while connecting server  - Data not sent ",e
				if @pretry >=@obj.config.connection_retry
					#@obj.shutdown= true
				else
					@obj.log.info "[connector] Exception found in Get request - Retrying - Count - #{@gretry}"
					return get uri
				end
			end
			@gretry = 0
		end

		def url(uri)
			ru=nil
			p="https"
			if(!@obj.config.is_secured)
				p="http"
			end			 	
			if(@obj.config.license_key != nil)
				if(!@obj.config.license_key.empty?)
					if(@obj.config.apmhost != nil && !@obj.config.apmhost.empty?)
						u = @obj.config.apmhost+uri
					else
						u = @obj.config.site24x7url+uri
					end
				else
					#empty license key - print error
					@obj.log.info "license key is present, but empty"
				end
			else
				@obj.log.info "license key is null"
				u = p+"://"+@obj.config.apmhost+":#{@obj.config.apmport}/"+uri
			end
			begin
				ru = URI.parse(u)
			rescue
				raise URI::InvalidURIError, "Invalid url '#{ru}'"
			end

			if (ru.class != URI::HTTP && ru.class != URI::HTTPS)
				raise URI::InvalidURIError, "Invalid url '#{u}'"
			end
			ru
		end

		def connection(url)

			if (@obj.config.proxyneeded)
				@obj.log.debug "[connect] Through Proxy"
				con = Net::HTTP::Proxy(@obj.config.proxy_host, @obj.config.proxy_port,@obj.config.proxy_user,@obj.config.proxy_pass).new(url.host, url.port)		
			else
				#@obj.log.info "Proxy Not Needed #{url.host} #{url.port}"
				con = Net::HTTP.new(url.host, url.port)
				#con.use_ssl=true
				#con.verify_mode=OpenSSL::SSL::VERIFY_NONE
				#@obj.log.info "connection = #{con}"
			end
			con=getScheme(con)
			con.open_timeout = @obj.constants.connection_open_timeout
			con.read_timeout = @obj.constants.connection_read_timeout
			con
		end

		def getScheme(con)
			if(@obj.config.license_key != nil || @obj.config.is_secured)
				#@obj.log.info "[connect] Secured"
				#con = Net::HTTP::Proxy(@obj.config.proxy_host, @obj.config.proxy_port,@obj.config.proxy_user,@obj.config.proxy_pass).new(url.host, url.port)		
				con.use_ssl=true
				con.verify_mode=OpenSSL::SSL::VERIFY_NONE
			end
			con
		end

		def responseParser resp
			if resp.kind_of? Net::HTTPOK
				rawData = resp.body
				if rawData.length>=2
					rBody = JSON.parse(rawData)
					result = rBody["result"]
					data = rBody["data"]
					if !@obj.util.getBooleanValue result
						if data!=nil
							if data.has_key?("exception")
								raise Exception.new("Exception from server - "+data["exception"])
							end
						end

					end
					if data!=nil
					       if data.has_key?(@obj.constants.response_code)
							srCode = data[@obj.constants.response_code]
							response_action srCode
					       end
					       if data.has_key?(@obj.constants.custom_config_info)
					        config_info = data[@obj.constants.custom_config_info]
  					       if data.has_key?(@obj.constants.agent_specific_info)
  					         config_info = config_info.merge(data[@obj.constants.agent_specific_info])
  					       end
  					       update_config config_info
					       end
					end
					return data
				end
				return rawData
			else
				raise Exception.new("Http Connection Response Error #{resp.to_s}")
			end
		end



		def response_action rCode
			case rCode
			when @obj.constants.licence_expired then
				@obj.log.info "License Expired. Going to shutdown"
				raise Exception.new("License Expired. Going to shutdown")
			when @obj.constants.licence_exceeds then
				@obj.log.info "License Exceeds. Going to shutdown"
				raise Exception.new("License Exceeds. Going to shutdown")
			when @obj.constants.delete_agent then
				@obj.log.info "Action from Server - Delete the Agent. Going to shutdown and remove the Agent"
				deleteAgent
				raise Exception.new("Action from Server - Delete the Agent. Going to shutdown and remove the Agent")
			when @obj.constants.unmanage_agent then
				@obj.log.info "Action from Server - Unmanage the Agent. Going to  Stop the DC - Disabling the Agent"
				unManage
			when @obj.constants.manage_agent then
				@obj.log.info "Action from Server - Manage the Agent. Going to Sart the DC - Enabling the Agent"
				manage	
			end
		end

		def update_config configInfo
			existingConfigInfo = @obj.config.getAgentConfigData
			sendUpdate = "false"
			existingConfigInfo.each do|key,value|
				if key != "last.modified.time"
					newValue = configInfo[key]
					if key == "sql.capture.enabled" || key == "transaction.trace.enabled" || key == "transaction.trace.sql.parametrize"
						if newValue
							newValue = 1
						else
							newValue = 0
						end
					end
					if value != newValue
						sendUpdate = "true"
					end
				end
			end
			if sendUpdate == "true"
				@obj.log.info "Action from Server - Agent configuration updated from UI. Going to update the same in apminsight.conf file"
				@obj.log.info "config info = #{configInfo}"
				@obj.config.update_config configInfo
			end
		end

		def unManage
			uManage = Hash.new
			uManage["agent.id"]=@obj.config.instance_id
			uManage["agent.enabled"]=false	
			@obj.config.updateAgentInfoFile uManage
		end

		def manage
			uManage = Hash.new
			uManage["agent.id"]=@obj.config.instance_id
			uManage["agent.enabled"]=true	
			@obj.config.updateAgentInfoFile uManage
		end

		def deleteAgent
			uManage = Hash.new
			uManage["agent.id"]=@obj.config.instance_id
			uManage["agent.enabled"]=false	
			@obj.config.updateAgentInfoFile uManage
			begin
				File.delete(@obj.constants.agent_conf)
			rescue Exceptione=>e
				@obj.log.logException "#{e.message}",e
			end
		end

	end#c
end#m
