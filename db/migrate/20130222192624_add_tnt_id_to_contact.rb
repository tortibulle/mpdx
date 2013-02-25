class AddTntIdToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :tnt_id, :integer
    add_index  :contacts, :tnt_id
  end
end
