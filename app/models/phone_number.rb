class PhoneNumber < ActiveRecord::Base
  include HasPrimary
  @@primary_scope = :person

  has_paper_trail :on => [:destroy],
                  :meta => { related_object_type: 'Person',
                             related_object_id: :person_id }


  belongs_to :person

  before_save :clean_up_number

  # attr_accessible :number, :primary, :country_code, :location, :remote_id

  def self.add_for_person(person, attributes)
    attributes = attributes.except(:_destroy)
    if number = person.phone_numbers.find_by_number(strip_number(attributes['number']))
      number.update_attributes(attributes)
    else
      attributes['primary'] = (person.phone_numbers.present? ? false : true) if attributes['primary'].nil?
      new_or_create = person.new_record? ? :new : :create
      number = person.phone_numbers.send(new_or_create, attributes)
    end
    number
  end

  def self.strip_number(number)
    number.gsub(/\W/,'') if number
  end

  def clean_up_number
    strip_number!
    self.country_code ||= '1' if number.length == 10
    true
  end

  private

  def strip_number!
    if number.first == '+' && (match = number.match(/\+(\d+) /))
      self.number = number.sub(match[0], '')
      self.country_code = match[1]
    end
    self.number = PhoneNumber.strip_number(number)
  end

end
