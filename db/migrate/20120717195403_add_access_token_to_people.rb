class AddAccessTokenToPeople < ActiveRecord::Migration
  def change
    add_column :people, :access_token, :string, limit: 32

    add_index :people, :access_token, unique: true
  end
end
