# encoding: utf-8

class ImageUploader < CarrierWave::Uploader::Base
  include Cloudinary::CarrierWave

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def cache_dir
    "#{Rails.root}/tmp/uploads"
  end
  # Process files as they are uploaded:
  process resize_to_limit: [500, 500]

  version :large do
    eager
    process resize_and_pad: [180, 180]
  end

  version :square do
    eager
    cloudinary_transformation width: 50, height: 50, crop: :fill, gravity: :face
  end

  def extension_white_list
    %w(jpg jpeg png)
  end
end
