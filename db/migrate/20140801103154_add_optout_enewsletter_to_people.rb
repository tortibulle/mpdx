class AddOptoutEnewsletterToPeople < ActiveRecord::Migration
  def change
    add_column :people, :optout_enewsletter, :boolean, default: false
  end
end