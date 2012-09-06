class ContactSerializer < ActiveModel::Serializer
  include ActionView::Helpers::AssetTagHelper

  embed :ids, include: true

  attributes :id, :name, :pledge_amount, :pledge_frequency, :pledge_start_date, :status, :deceased,
             :notes, :notes_saved_at, :next_ask, :never_ask, :likely_to_give, :church_name, :send_newsletter,
             :magazine, :last_activity, :last_appointment, :last_letter, :last_phone_call, :last_pre_call,
             :last_thank, :avatar

  has_many :people, :addresses

  def avatar
    '/assets/avatar.png'
  end

end
