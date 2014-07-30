class AddOptoutNewsletterToEmailAddresses < ActiveRecord::Migration
  def change
    add_column :email_addresses, :optout_newsletter, :boolean, default: false
  end
end