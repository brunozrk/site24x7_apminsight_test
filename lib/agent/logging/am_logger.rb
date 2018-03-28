
require "logger"

module ManageEngine
	class APMLogger
		@apmlog=nil;
		def initialize
			@obj=ManageEngine::APMObjectHolder.instance
			path = getLogsPath
			#puts "#{path}"
			if  Dir[path] == []
				Dir.mkdir(path)
			end
			path= path + '/apm.log'
			#puts "#{path}"
#			file = open(path, File::WRONLY | File::APPEND | File::CREAT)
			@apmlog = Logger.new(path, 10, 5 * 1024 * 1024)
			#	@apmlog = Logger.new(file)
			@apmlog.level = Logger::INFO
			@apmlog.datetime_format = "%Y-%m-%d %H:%M:%S"	
			@apmlog.formatter = proc do |severity, datetime, progname, msg|
				"[#{datetime}|#{Process.pid}][#{severity}]:#{msg}\n"
			end
			@apmlog.debug("[LOGGER] APM Agent Logging Initialized")

		end 


		def	getLogsPath
			props = {}
			begin
				if FileTest.exists?(@obj.constants.apm_conf)
				propsFile=File.open(@obj.constants.apm_conf, 'r') 
				propsFile.read.each_line do |line|
					line.strip!
					if (line[0] != ?# and line[0] != ?=)
						i = line.index('=')
						if (i)
							props[line[0..i - 1].strip] = line[i + 1..-1].strip
						else
							props[line] = ''
						end
					end
				end
				else
					puts "ManageEngine Ruby Agent Configuration File Not exist in #{@obj.constants.apm_conf}.\n Duplicate file will be available in <Gems Folder>/apm-agent/lib/config "
				end
			rescue Exception=>e
				puts "Problem in Reading Property File : \n #{e.message} \n  #{e.backtrace}"
			ensure
				#
			end
			if props["apminsight.log.dir"]!=nil
				return props["apminsight.log.dir"]
			else
				return "./log"
			end

		end

		def setLevel level
			level =  level.upcase
			case level.upcase 
			when "INFO" then @apmlog.level = Logger::INFO
			when "DEBUG" then @apmlog.level = Logger::DEBUG
			when "WARN" then @apmlog.level = Logger::WARN
			when "ERROR" then @apmlog.level = Logger::ERROR
			when "FATAL" then @apmlog.level = Logger::FATAL
			when "FINE" then @apmlog.level = Logger::DEBUG
			when "SEVERE" then @apmlog.level = Logger::ERROR
			when "WARNING" then @apmlog.level = Logger::WARN
			else 
				@apmlog.level = Logger::DEBUG
			end
		end

		def info(msg)
			@apmlog.info(msg)
		end

		def debug(msg)
			@apmlog.debug(msg)
		end

		def warn(msg)
			@apmlog.warn(msg)
		end

		def error(msg)
			@apmlog.error(msg)
		end

		def fatal(msg)
			@apmlog.fatal(msg)
		end


		def logException(msg,e)
			@apmlog.warn( "#{msg} => #{e.message}")
			@apmlog.warn( "Message  : #{msg}\nTrace :\n#{e.backtrace}")
		end

		def close
			@apmlog.close
		end
	end
end
