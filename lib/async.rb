require 'resque/plugins/lock'
# require 'resque/plugins/retry'
module Async
  module ClassMethods
    #extend Resque::Plugins::Lock
    #extend Resque::Plugins::Retry
    #@retry_limit = 3
    #@retry_delay = 60

    #@retry_exceptions = [ActiveRecord::RecordNotFound]

    # This will be called by a worker when a job needs to be processed
    def perform(id, method, *args)
      @retries = 0
      if id
        begin
          find(id).send(method, *args)
        rescue ActiveRecord::RecordNotFound
          if @retries < 3
            @retries += 1
            sleep(20)
            retry
          else
            raise
          end
        end
      else
        new.send(method, *args)
      end
    end
  end

  # We can pass this any Repository instance method that we want to
  # run later.
  def async(method, *args)
    Resque.enqueue(self.class, id, method, *args)
  end

  def self.included(base)
    base.send :extend, ClassMethods
  end
end
