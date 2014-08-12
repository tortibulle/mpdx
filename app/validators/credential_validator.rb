class CredentialValidator < ActiveModel::Validator
  def validate(record)
    # we don't want this error to show up if there is already an error
    # on username or password or organization
    return if record.errors[:username].present? || record.errors[:password].present? || record.errors[:organization_id].present?
    return if valid_credentials?(record)

    record.errors[:base] << _('Your username and password for %{org} are invalid.').localize % { org: record.organization }
  end

  private

  def valid_credentials?(record)
    return false unless record.organization
    return true unless record.requires_username_and_password?
    return record.username.present? && record.password.present? && record.organization.api(record).validate_username_and_password
  rescue OrgAccountInvalidCredentialsError
    return false
  rescue DataServerError => e
    return false if e.message.include?('user')

    raise
  end
end
