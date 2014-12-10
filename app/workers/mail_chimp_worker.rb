class MailChimpWorker
  include Sidekiq::Worker

  sidekiq_options backtrace: true, unique: true

  def perform(klass_str, id, method, *args)
    klass = klass_str.constantize
    begin
      object = id ? klass.find(id) : klass
      object.send(method, *args)
    rescue ActiveRecord::RecordNotFound
      # If this instance has been deleted, oh well.
    end
  end
end
