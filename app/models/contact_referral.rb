class ContactReferral < ActiveRecord::Base
  belongs_to :referred_by, class_name: 'Contact', foreign_key: :referred_by_id
  belongs_to :referred_to, class_name: 'Contact', foreign_key: :referred_to_id

  attr_accessible :referred_by_id, :referred_to_id
end
