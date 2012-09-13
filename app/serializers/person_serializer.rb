class PersonSerializer < ActiveModel::Serializer
  include DisplayCase::ExhibitsHelper
  
  embed :ids, include: true
  attributes :id, :first_name, :last_name, :middle_name, :birthday_month, :birthday_year,
             :anniversary_month, :anniversary_year, :anniversary_day, :title, :suffix, :gender,
             :marital_status, :master_person_id, :birthday_day, :avatar

  has_many :phone_numbers, :email_addresses

  def avatar
    person_exhibit = exhibit(object)
    '/assets/' + person_exhibit.avatar
  end
end
