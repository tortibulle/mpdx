class ChangeActivitySubjectMaxLength < ActiveRecord::Migration
  def change
    change_column :activities, :subject, :string, limit: 2000
  end
end
