class AccountList < ActiveRecord::Base
  belongs_to :designation_profile
end

class AddAccountListIdToDesignationProfile < ActiveRecord::Migration
  def change
    add_column :designation_profiles, :account_list_id, :integer
    add_index :designation_profiles, :account_list_id
    AccountList.find_each do |al|
      if al.designation_profile
        al.designation_profile.update_column(:account_list_id, al.id)
      end
    end
  end
end
