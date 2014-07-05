class PrayerLettersAccountsController < ApplicationController
  def create
    auth_hash = request.env['omniauth.auth']

    prayer_letters_account.attributes = {
                                          token: auth_hash.credentials.token,
                                          secret: auth_hash.credentials.secret,
                                          valid_token: true
                                        }
    prayer_letters_account.save
    flash[:notice] = _('MPDX is now uploading your newsletter recipients to PrayerLetters.com.')

    redirect_to integrations_settings_path
  end

  def destroy
    current_account_list.prayer_letters_account.destroy
    redirect_to integrations_settings_path
  end

  def sync
    flash[:notice] = _('MPDX is now uploading your newsletter recipients to PrayerLetters.com.') # We'll send you an email to let you know when we're done.
    prayer_letters_account.queue_subscribe_contacts
    redirect_to :back
  end

  private

  def prayer_letters_account
    @prayer_letters_account ||= current_account_list.prayer_letters_account ||
                          current_account_list.build_prayer_letters_account
  end
end
