class AddSettingsToAccountList < ActiveRecord::Migration
  def change
    add_column :account_lists, :settings, :text
  end
end
