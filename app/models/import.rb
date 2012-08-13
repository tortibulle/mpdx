require 'async'
require 'csv'
require 'tnt_import_validator'

class Import < ActiveRecord::Base
  include Async

  belongs_to :user

  def self.queue() :import; end

  mount_uploader :file, ImportUploader
  belongs_to :account_list
  attr_accessible :file, :importing, :source, :file_cache, :override, :tags
  validates_with TntImportValidator, if: lambda {|import| 'tnt' == import.source }

  def queue_import_contacts
    async(:import_contacts)
  end

  def import_contacts
    "#{source.titleize}Import".constantize.new(self).import_contacts
  ensure
    update_column(:importing, false)
  end
end
