class ChangePledgeFrequencyToDecimal < ActiveRecord::Migration
  def self.up
    change_column :contacts, :pledge_frequency, :decimal
    execute <<-SQL
      update contacts set pledge_frequency = pledge_frequency * 1.0
    SQL
  end

  def self.down
    change_column :contacts, :pledge_frequency, :integer
  end
end
