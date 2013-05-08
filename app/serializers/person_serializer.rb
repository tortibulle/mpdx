class PersonSerializer < ActiveModel::Serializer
  include DisplayCase::ExhibitsHelper

  embed :ids, include: true
  ATTRIBUTES = [:id, :first_name, :last_name, :middle_name, :birthday_month, :birthday_year,
                :anniversary_month, :anniversary_year, :anniversary_day, :title, :suffix, :gender,
                :marital_status, :master_person_id, :birthday_day, :avatar]

  attributes *ATTRIBUTES

  INCLUDES = [:phone_numbers, :email_addresses]
  INCLUDES.each do |i|
    has_many i
  end

  def avatar
    person_exhibit = exhibit(object)
    person_exhibit.avatar(:large)
  end

  def attributes
    includes = scope[:include] if scope.is_a? Hash
    if includes.present?
      hash = {}
      includes.each do |rel|
        if ATTRIBUTES.include?(rel.to_sym)
          hash[rel.to_sym] = object.send(rel.to_sym)
        end
      end
    else
      hash = super
    end

    hash
  end
  
  def include_associations!
    includes = scope[:include] if scope.is_a? Hash
    includes.each do |rel|
      if INCLUDES.include?(rel.to_sym)
        include!(rel.to_sym)
      end
    end if includes
  end
end
