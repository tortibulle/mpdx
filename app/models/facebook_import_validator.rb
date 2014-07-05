class FacebookImportValidator < ActiveModel::Validator
  def validate(import)
    # To import from facebook we need to have a valid token
    if !import.user.facebook_account ||
       import.user.facebook_account.token_missing_or_expired?
      import.errors[:base] << _('The link to your facebook account needs to be refreshed. <a href="/auth/facebook">Click here to re-connect to facebook</a> then try your import again.')
    end
  end
end
