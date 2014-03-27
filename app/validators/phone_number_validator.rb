class PhoneNumberValidator < ActiveModel::EachValidator
  attr_reader :record, :attribute, :value

  def validate_each(record, attribute, value)
    @record, @attribute, @value = record, attribute, value

    add_error unless valid?
  end

  private

  def valid?
    GlobalPhone.parse(value)
  end

  def add_error
    if message = options[:message]
      record.errors[attribute] << message
    else
      record.errors.add(attribute, :invalid)
    end
  end
end
