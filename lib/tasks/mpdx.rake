namespace :mpdx do
  task merge_accounts: :environment do
    def merge_contacts(al)
      contacts = al.contacts.order('contacts.created_at')
      contacts.reload
      contacts.each do |contact|
        other_contact = al.contacts.where(name: contact.name).where("id <> #{contact.id}").first
        if other_contact && other_contact.donor_accounts.first == contact.donor_accounts.first
          contact.merge(other_contact)
          merge_contacts(al)
          return
        end
      end
    end

    def merge_account_lists
      AccountList.all.each do |al|
        other_list = AccountList.where(name: al.name).where("id <> #{al.id} AND name like 'Staff Account (%'").first
        if other_list# && other_contact.donor_accounts.first == contact.donor_accounts.first
          puts other_list.name
          al.merge(other_list)
          merge_contacts(al)
          merge_account_lists
          return
        end
      end
    end
    merge_account_lists


  end
end


