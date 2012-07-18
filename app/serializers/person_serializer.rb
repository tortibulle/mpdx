class PersonSerializer < ActiveModel::Serializer
  embed :ids
  attributes :id, :first_name, :last_name, :middle_name, :birthday_month, :birthday_year,
             :anniversary_month, :anniversary_year, :anniversary_day, :title, :suffix, :gender,
             :marital_status, :master_person_id, :birthday_day

  has_many :phone_numbers, :email_addresses
end
