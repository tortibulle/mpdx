class PhoneNumber < ActiveRecord::Base
  belongs_to :person

  before_save :clean_up_number
  after_save :ensure_only_one_primary

  attr_accessible :number, :primary, :country_code, :location

  def self.add_for_person(person, attributes)
    attributes = attributes.except(:_destroy)
    if number = person.phone_numbers.find_by_number(strip_number(attributes['number']))
      number.update_attributes(attributes)
    else
      primary = person.phone_numbers.present? ? false : true
      new_or_create = person.new_record? ? :new : :create
      number = person.phone_numbers.send(new_or_create, attributes.merge(primary: primary))
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

    def ensure_only_one_primary
      primary_numbers = self.person.phone_numbers.where(primary: true)
      primary_numbers[0..-2].map {|e| e.update_column(:primary, false)} if primary_numbers.length > 1
    end
end
