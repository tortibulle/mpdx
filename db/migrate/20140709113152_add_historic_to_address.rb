class AddHistoricToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :historic, :boolean, default: false
  end
end