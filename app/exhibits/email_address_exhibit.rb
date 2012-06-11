class EmailAddressExhibit < Exhibit

  def self.applicable_to?(object)
    object.is_a?(EmailAddress)
  end

  def to_s
    @context.mail_to(email).html_safe
  end


end
