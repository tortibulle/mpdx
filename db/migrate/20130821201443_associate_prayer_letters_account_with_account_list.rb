class PrayerLettersAccount < ActiveRecord::Base
end

class AssociatePrayerLettersAccountWithAccountList < ActiveRecord::Migration
  def up
    rename_table :person_prayer_letters_accounts, :prayer_letters_accounts
    add_column :prayer_letters_accounts, :account_list_id, :integer
    PrayerLettersAccount.find_each do |pl|
      al = User.find(pl.person_id).account_lists.first
      pl.update_column(:account_list_id, al.id)
    end
    remove_column :prayer_letters_accounts, :person_id
    add_index :prayer_letters_accounts, :account_list_id
  end

  def down
    add_column :prayer_letters_accounts, :person_id, :integer
    PrayerLettersAccount.find_each do |pl|
      u = AccountList.find(pl.account_list_id).users.first
      pl.update_column(:account_list_id, u.id)
    end
    remove_column :prayer_letters_accounts, :account_list_id
    rename_table :prayer_letters_accounts, :person_prayer_letters_accounts
  end
end
