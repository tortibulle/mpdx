class AddNotDuplicatedWithToPeople < ActiveRecord::Migration
  def change
    add_column :people, :not_duplicated_with, :string, limit: 2000
  end
end
