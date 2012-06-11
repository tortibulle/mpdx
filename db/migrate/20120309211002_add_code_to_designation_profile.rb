class AddCodeToDesignationProfile < ActiveRecord::Migration
  def change
    add_column :designation_profiles, :code, :string

  end
end
