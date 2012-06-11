class RemoveUserColumns < ActiveRecord::Migration
  def change
    remove_column :people, :time_zone
    remove_column :people, :locale
  end
end
