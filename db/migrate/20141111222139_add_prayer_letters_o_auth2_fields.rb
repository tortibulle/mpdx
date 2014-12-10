class AddPrayerLettersOAuth2Fields < ActiveRecord::Migration
  def change
    add_column :prayer_letters_accounts, :oauth2_token, :string
  end
end
