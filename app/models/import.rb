require 'async'
require 'csv'
require 'tnt_import_validator'

class Import < ActiveRecord::Base
  include Async

  belongs_to :user

  def self.queue() :import; end

  mount_uploader :file, ImportUploader
  belongs_to :account_list
  # attr_accessible :file, :importing, :source, :file_cache, :override, :tags
  validates_inclusion_of :source, in: %[facebook twitter linkedin tnt]
  validates_with TntImportValidator, if: lambda {|import| 'tnt' == import.source }
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
      true
    rescue => e
      ImportMailer.failed(self).deliver
      raise e
    end
  ensure
    update_column(:importing, false)
  end

end
