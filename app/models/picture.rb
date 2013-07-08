class Picture < ActiveRecord::Base
  include HasPrimary
  @@primary_scope = :picture_of

  mount_uploader :image, ImageUploader

  belongs_to :picture_of, polymorphic: true, touch: true
end
