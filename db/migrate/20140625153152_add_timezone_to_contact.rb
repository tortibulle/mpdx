class AddTimezoneToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :timezone, :string
  end
end
