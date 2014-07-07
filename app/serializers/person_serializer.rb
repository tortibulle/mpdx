class PersonSerializer < ActiveModel::Serializer
  include DisplayCase::ExhibitsHelper

  embed :ids, include: true
  ATTRIBUTES = [:id, :first_name, :last_name, :middle_name, :birthday_month, :birthday_year,
                :anniversary_month, :anniversary_year, :anniversary_day, :title, :suffix, :gender,
                :marital_status, :master_person_id, :birthday_day, :avatar]

  attributes(*ATTRIBUTES)

  INCLUDES = [:phone_numbers, :email_addresses, :facebook_accounts]
  INCLUDES.each do |i|
    has_many i
  end

  def avatar
    person_exhibit = exhibit(object)
    person_exhibit.avatar(:large)
  end
end
