class EmailAddressExhibit < DisplayCase::Exhibit
  def self.applicable_to?(object)
    object.class.name == 'EmailAddress'
  end

  def to_s
    @context.mail_to(email).html_safe
  end
end
