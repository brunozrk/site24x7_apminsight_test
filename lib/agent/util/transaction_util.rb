module ManageEngine
  class TransactionUtil
    
    def initialize
      @obj = ManageEngine::APMObjectHolder.instance
    end
    
    def normalizeName(txnName)
      if (txnName != nil)
        txnName.gsub!(/\/\d+/, "/*") # Replace all numbers with *
        # Transaction merge patterns - provided by user
        @obj.config.url_merge_pattern.each do |key, val|
          if (txnName.match(key) != nil)
            txnName=val
            break
          end
        end # do
      end # if (txnName != nil)
      txnName
    end # def normalizeName
    
    def listen?(txnName)
      if (txnName != nil)
        @obj.config.txn_skip_listen.each do |pattern|
          pattern = pattern.start_with?('.*') ? pattern : ('.' + pattern)
          if (txnName.match(pattern) != nil)
            return false
          end
        end # do
      end
      true
    end # def listen?
    
  end
end