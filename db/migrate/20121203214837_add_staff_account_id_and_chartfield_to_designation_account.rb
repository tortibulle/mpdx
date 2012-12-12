class AddStaffAccountIdAndChartfieldToDesignationAccount < ActiveRecord::Migration
  def change
    add_column :designation_accounts, :staff_account_id, :string
    add_column :designation_accounts, :chartfield, :string
  end
end
