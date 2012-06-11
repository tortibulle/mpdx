class AddEmailToPersonGoogleAccount < ActiveRecord::Migration
  def change
    add_column :person_google_accounts, :email, :string, null: false

  end
end
