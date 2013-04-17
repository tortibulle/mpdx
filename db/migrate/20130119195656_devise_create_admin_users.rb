class DeviseCreateAdminUsers < ActiveRecord::Migration
  def migrate(direction)
    super
    # Create a default user
    AdminUser.create!(:email => 'josh.starcher@cru.org', :guid => 'F167605D-94A4-7121-2A58-8D0F2CA6E026') if direction == :up
  end

  def migrate(direction)
    super
    # Create a default user
    AdminUser.create!(:email => 'admin@example.com', :password => 'password', :password_confirmation => 'password') if direction == :up
  end

  def change
    create_table(:admin_users) do |t|
      ## Database authenticatable
      t.string :email,              :null => false, :default => ""
      t.string :guid, null: false

      ## Trackable
      t.integer  :sign_in_count, :default => 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Token authenticatable
      t.string :authentication_token


      t.timestamps
    end

    add_index :admin_users, :email,                :unique => true
    add_index :admin_users, :guid, :unique => true
    add_index :admin_users, :authentication_token, :unique => true
  end
end
