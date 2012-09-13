class CreateSocialItems < ActiveRecord::Migration
  def change
    create_table :social_items do |t|

      t.timestamps
    end
  end
end
