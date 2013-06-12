class ChangePledgeFrequencyToDecimal < ActiveRecord::Migration
  def self.up
   change_column :contacts, :pledge_frequency, :decimal
  end

  def self.down
   change_column :contacts, :pledge_frequency, :integer
  end
end
