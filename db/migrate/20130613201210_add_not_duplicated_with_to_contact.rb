class AddNotDuplicatedWithToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :not_duplicated_with, :string, limit: 2000
  end
end
