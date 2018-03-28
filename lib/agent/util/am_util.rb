require 'socket'
module ManageEngine
	class APMUtil
		
		def setLogger log
			@log = log
		end

		#Reads the Property Files and returns a Hashes
		def	readProperties filepath
			props = {}
			begin
				propsFile=File.open(filepath, 'r') 
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
			rescue Exception=>e
				@log.info "Problem in Reading Property File :  #{e.message} "
				@log.error "#{e.backtrace}"
			ensure
					propsFile.close
			end
			props
		end

		#write the Properties into the Property file
		def writeProperties(f,props)
			begin 
				file = File.new(f,"w+")
				props.each {|key,value| file.puts "#{key}=#{value}\n"}
			rescue Exception=>e
				@log.info "Problem in Writing Property File : \n File : #{f}"
				@log.logException "#{e.message}",e
			ensure
				file.close
			end
		end

		def copyFiles src, dest
			result = false
			begin
			srcFile = File.open(src)
			destFile = File.open(dest , "w")
			destFile.write( srcFile.read(100) ) while not srcFile.eof?
			result = true
			rescue	Exception=>e
				@log.info "Problem in Copying File : \n File : #{src} to #{dest}"
				@log.logException "#{e.message}",e
				result = false;
			ensure
				srcFile.close
				destFile.close
			end

			result
		end

	
	 def getBooleanValue(str)
    	if str == true || str == "true" || str == "True" || str == "TRUE"
		 	return true
		else
			return false
		end
  	end
		
	def currenttimemillis
		(Time.now.to_f*1000).to_i
	end


	def getArray value,sep
		arr = Array.new
		if(value!=nil && value.length>0)
			arr = value.split(sep)
		end
		arr
	end
	def isPortBusy(port)
        Timeout::timeout(1) do
         begin
		 	TCPSocket.new('localhost', port).close
            true
         rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            false
		end
		end
		rescue Timeout::Error
			false
    end

	def is_integer(val)
  		Integer(val)
		rescue ArgumentError
  			false
		else
  			true
	end

	def is_float(val)
		Float(val)
		rescue ArgumentError
  			false
		else
  			true
	end

	def parametrizeQuery qry
		begin
			qry.gsub!(/'(.*?[^'])??'/,"?")
			qry.gsub!(/\"(.*?[^\"])??\"/,"?")
			qry.gsub!(/=.\d+/,"=?")
            qry.gsub!(/,.\d+/,", ?")
		rescue Exception=>e
			@log.info "Problem in Parameterizing query:  #{e.message} "
			@log.logException "#{e.message}",e
		end
		qry
	end

	  def formatStacktrace(stacktrace)
      strace = Array.new
      
      if (stacktrace != nil)
        begin
          stacktrace.each do |stackelement|
            temp = Array.new
            temp[0] = stackelement
            temp[1] = ""
            temp[2] = ""
            temp[3] = ""
            strace.push(temp)
            if (strace.size == 10)
              break;
            end
          end
        rescue Exception=>e
          @log.logException "Error while formatting stack trace. #{e.message}", e
        end
      end
      
      strace
    end
	
	end#c
end#m
