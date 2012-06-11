require 'resque/plugins/lock'
module Async
  module ClassMethods
    extend Resque::Plugins::Lock
    #extend Resque::Plugins::Retry
    #@retry_limit = 3
    #@retry_delay = 60

    # This will be called by a worker when a job needs to be processed
    def perform(id, method, *args)
      if id
        find(id).send(method, *args)
      else
        new.send(method, *args)
      end
    end
  end

  # We can pass this any Repository instance method that we want to
  # run later.
  def async(method, *args)
    Resque.enqueue(self.class, id, method, *args) unless Rails.env.test?
  end

  def self.included(base)
    base.send :extend, ClassMethods
  end
end
