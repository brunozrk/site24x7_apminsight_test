module ManageEngine
  module Tracker
    class DatabaseTracker < DefaultTracker
      
      def sql(query)
        @query = format(query.dup)
      end
      
      def params(binds = [])
        @binds = binds
      end
      
      def sqlBacktrace(backtrace)
        @backtrace = backtrace
      end
      
      def getRawQuery
        @query
      end
      
      def getObfuscatedQuery
        ManageEngine::APMObjectHolder.instance.util.parametrizeQuery @query
      end
      
      def getCompleteQuery
        begin
          query = @query # Maintaining the original query
          if query != nil && @binds != nil && @binds.length > 0
            @binds.each do |ar|
              if query.index("?") != nil
                query["?"]=ar.value.to_s
              end
            end
            return query
          end
        rescue Exception=>exe
          @logger.logException "Not severe -#{exe.message}",exe
        end
        @query
      end
      
      # Returns array [db_operation, tablename]
      def getQueryInfo
        sql = @query
        sql.strip!
        sql.downcase!
        sqlArr = sql.split(" ")
        
        begin
          tableName = case sqlArr[0]
                 when "select" then sqlArr[sqlArr.index("from")+1]
                 when "insert" then sqlArr[sqlArr.index("into")+1]
                 when "update" then sqlArr[1]
                 when "delete" then sqlArr[sqlArr.index("from")+1]
                 when "create" then sqlArr[1] + sqlArr[2]
                 when "alter" then sqlArr[1] + sqlArr[2]
                 when "drop" then sqlArr[1] + sqlArr[2]
                 when "show" then sqlArr[1] 
                 when "describe" then sqlArr[1] 
                 else "-"
                 end
          
          return [sqlArr[0], tableName]
  
        rescue Exception=>e
          @logger.logException "#{e.message}",e
          return [sqlArr[0], '-']
        end
      end
      
      def format s
        s.gsub!("\"", '')
        s.gsub!("\n", '')
        s
      end
      
      def getAdditionalInfo
        info = super
        begin
          if (@query != nil)
            if (info == nil)
              info = Hash.new
            end
            
            obj = ManageEngine::APMObjectHolder.instance
            
            info["query"] = !obj.config.sql_capture_params ? getCompleteQuery : getObfuscatedQuery
            # send only one backtrace, Exception backtrace have more priority
            if (@backtrace != nil && @error == nil)
              info["stacktrace"] = obj.util.formatStacktrace(@backtrace)
            end
          end
        rescue Exception => e
          @logger.logException("Error updating additionalInfo in dbTracker.", e)
        end
                
        info
      end
      
      
      def to_s
        "#{@name} - #{@query}"
      end
      
    end
  end
end