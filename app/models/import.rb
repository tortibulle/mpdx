require 'async'

class Import < ActiveRecord::Base
  include Async
  include Sidekiq::Worker
  sidekiq_options queue: :import, retry: false, backtrace: true, unique: true

  belongs_to :user

  mount_uploader :file, ImportUploader
  belongs_to :account_list
  # attr_accessible :file, :importing, :source, :file_cache, :override, :tags
  validates :source, inclusion: { in: %w[facebook twitter linkedin tnt] }
  #validates_with TntImportValidator, if: lambda {|import| 'tnt' == import.source }
  validates_with FacebookImportValidator, if: lambda {|import| 'facebook' == import.source }

  after_commit :queue_import

  def queue_import
    async(:import)
  end

  private

  def import
    update_column(:importing, true)
    begin
      "#{source.titleize}Import".constantize.new(self).import
      ImportMailer.complete(self).deliver

      # clean up data
      account_list.merge_contacts
      true
    rescue => e
      ImportMailer.failed(self).deliver
      raise e
    end
  ensure
    update_column(:importing, false)
  end

end
