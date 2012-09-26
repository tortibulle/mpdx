class AddResultToActivity < ActiveRecord::Migration
  def change
    add_column :activities, :result, :string
  end
end
