class AddRemoteIdAndSourceToActivity < ActiveRecord::Migration
  def change
    add_column :activities, :remote_id, :string
    add_column :activities, :source, :string
  end
end
