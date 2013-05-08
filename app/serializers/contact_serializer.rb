class ContactSerializer < ActiveModel::Serializer
  include DisplayCase::ExhibitsHelper

  embed :ids, include: true

  ATTRIBUTES = [:id, :name, :pledge_amount, :pledge_frequency, :pledge_start_date, :status, :deceased,
                :notes, :notes_saved_at, :next_ask, :never_ask, :likely_to_give, :church_name, :send_newsletter,
                :magazine, :last_activity, :last_appointment, :last_letter, :last_phone_call, :last_pre_call,
                :last_thank, :avatar]

  attributes *ATTRIBUTES

  INCLUDES = [:people, :addresses]
  has_many *INCLUDES

  def include_associations!
    includes = scope[:include] if scope.is_a? Hash
    includes.each do |rel|
      if INCLUDES.include?(rel.to_sym)
        include!(rel.to_sym)
      end
    end if includes
  end

  def attributes
    includes = scope[:include] if scope.is_a? Hash
    if includes.present?
      attributes = includes.map(&:to_sym) & ATTRIBUTES
    else
      attributes = ATTRIBUTES
    end

    hash = {}
    attributes.each do |rel|
      value = send(rel.to_sym)
      hash[rel.to_sym] = value if value
    end

    if scope.is_a?(Hash) && scope[:since]
      hash[:deleted_people] = Version.where(item_type: 'Person', event: 'destroy', related_object_type: 'Contact', related_object_id: id).where("created_at > ?", Time.at(scope[:since].to_i)).pluck(:item_id)
      hash[:deleted_addresses] = Version.where(item_type: 'Address', event: 'destroy', related_object_type: 'Contact', related_object_id: id).where("created_at > ?", Time.at(scope[:since].to_i)).pluck(:item_id)
    end
    hash
  end

  def avatar
    contact_exhibit = exhibit(object)
    contact_exhibit.avatar(:large)
  end

  INCLUDES.each do |relationship|
    define_method(relationship) do
      add_since(object.send(relationship))
    end
  end
end
