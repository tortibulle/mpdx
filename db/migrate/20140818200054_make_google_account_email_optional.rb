class MakeGoogleAccountEmailOptional < ActiveRecord::Migration
  def change
    change_column :person_google_accounts, :email, :string, :null => true
  end
end
