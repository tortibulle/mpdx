# encoding: utf-8
require 'carrierwave/processing/mime_types'

class ImportUploader < CarrierWave::Uploader::Base
  include CarrierWave::MimeTypes

  process :set_content_type

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(xml)
  end

end
