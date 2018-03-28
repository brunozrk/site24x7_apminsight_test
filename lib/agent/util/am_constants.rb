
module ManageEngine
	class APMConstants

		attr_reader :apm_gem,:s247_apm_gem,:apm_conf,:agent_conf,:connection_open_timeout,:connection_read_timeout,:connect_uri,:connect_data_uri,:connect_trace_uri,:connect_config_update_uri,:site24x7USurl, :site24x7EUurl, :mergepattern_conf
		attr_reader :licence_exceeds,:licence_expired,:unmanage_agent,:manage_agent,:agent_config_updated,:error_notfound,:error_server,:delete_agent,:response_code,:custom_config_info, :agent_specific_info
		attr_reader :mf_transaction,:mf_separator,:mf_db,:mf_apdex,:mf_namespace,:mf_name,:mf_all,:agent_store,:agent_lock,:mf_overflow
		attr_reader :mf_logmetric, :mf_logmetric_warning, :mf_exception_st, :mf_err_st, :mf_loginfo, :mf_loginfo_time, :mf_loginfo_level, :mf_loginfo_str, :mf_loginfo_err_clz, :mf_loginfo_st, :mf_loginfo_level_warn
		
		def initialize
			
			#File path for APM Conf file
			@apm_gem="apminsight"
			@s247_apm_gem="site24x7_apminsight"
			
			#File path for APM Conf file
			@apm_conf="apminsight.conf"

			#file path for agent id, enable details
			@agent_conf="apminsight.info"

			#file path for agent data store lock
			@agent_lock="apminsight.lock"
			
			#file path for agent data store lock
			@agent_store="apminsight.store"
			
			#file name for url merge patterns
			@mergepattern_conf="transaction_merge_patterns.conf"


			#Timeout for opening Connections
			@connection_open_timeout=60

			#Timeout for Reading data from Connections
			@connection_read_timeout=60
			
			#Connection uri
			@connect_uri="arh/connect"
			
			#Connection uri for data
			@connect_data_uri="arh/data?instance_id="

			#Connection uri for trace
			@connect_trace_uri="arh/trace?instance_id="

			#Connection uri for config update
			@connect_config_update_uri="arh/agent_config_update?instance_id="
			
			#Site24x7 url for agent communication
			@site24x7USurl="https://plusinsight.site24x7.com/"

			@site24x7EUurl = "https://plusinsight.site24x7.eu/"
			
			#Response Codes 
			@licence_expired = 701
			@licence_exceeds = 702
			@delete_agent = 900
			@unmanage_agent =910
			@manage_agent = 911
			@agent_config_updated = 920
			@error_notfound = 404
			@error_server = 500
			@response_code = "response-code"
			@custom_config_info = "custom_config_info"
			@agent_specific_info = "agent_specific_info"

			#Metrics Formatter -mf
			@mf_apdex = "apdex"
			@mf_namespace = "ns"
			@mf_name = "name"
			@mf_all = "all"

			@mf_separator = "/"
			@mf_transaction = "transaction" + @mf_separator + "http"
			@mf_db = "db"
			@mf_overflow = "0verf10w"

      @mf_logmetric = "logmetric"
      @mf_logmetric_warning = "warning"
      @mf_err_st = "err_st"
      @mf_exception_st = "exception_st"
      @mf_loginfo = "loginfo"
      @mf_loginfo_time = "time"
      @mf_loginfo_level = "level"
      @mf_loginfo_str = "str"
      @mf_loginfo_err_clz = "err_clz"
      @mf_loginfo_st = "st"
      @mf_loginfo_level_warn = "WARN"

		end

		def setLicenseKey lkey
			@apm_gem="site24x7_apminsight"
			@connect_data_uri="arh/data?license.key="+lkey+"&instance_id="
			@connect_trace_uri="arh/trace?license.key="+lkey+"&instance_id="
			@connect_config_update_uri="arh/agent_config_update?license.key="+lkey+"&instance_id="
		end
	end
end
