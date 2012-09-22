class CredentialValidator < ActiveModel::Validator
  def validate(record)

    # we don't want this error to show up if there is already an error
    # on username or password or organization
    unless record.errors[:username].present? || record.errors[:password].present? || record.errors[:organization_id].present?
      unless valid_credentials?(record)
        record.errors[:base] << I18n.t('data_server.invalid_username_password', org: record.organization)
      end
    end
  end

  private
    def valid_credentials?(record)
      return false unless record.organization
      if record.requires_username_and_password?
        begin
          return record.username.present? && record.password.present? && record.organization.api(record).validate_username_and_password
        rescue OrgAccountInvalidCredentialsError => e
          return false
        rescue DataServerError => e
          if e.message.include?('user')
            return false
          else
            raise
          end
        end
      else
        true
      end
    end
end
