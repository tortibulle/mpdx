require 'spec_helper'

describe NotificationType::StoppedGiving do
  let!(:stopped_giving) { NotificationType::StoppedGiving.first_or_initialize }
  let!(:da) { create(:designation_account_with_donor) }
  let(:contact) { da.contacts.financial_partners.first }

  describe '.check' do
    context 'direct deposit donor' do
      before do
        contact.update_attributes(direct_deposit: true, pledge_received: true)
      end

      it 'adds a notification if late' do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 60.days.ago)
        notifications = stopped_giving.check(contact.account_list)
        notifications.length.should == 1
      end

      it "skips people with future pledge_start_date" do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 60.days.ago)
        contact.update_attributes(pledge_start_date: 1.day.from_now)
        notifications = stopped_giving.check(contact.account_list)
        notifications.length.should == 0
      end

      it "doesn't add a notification if not late" do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 37.days.ago)
        notifications = stopped_giving.check(contact.account_list)
        notifications.length.should == 0
      end

      it "doesn't add a notification if the contact is on a different account list with a shared designation account" do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 60.days.ago)
        account_list2 = create(:account_list)
        account_list2.account_list_entries.create!(designation_account: da)
        notifications = stopped_giving.check(account_list2)
        notifications.length.should == 0
      end
    end

    context 'non-direct deposit donor' do
      before do
        contact.update_attributes(pledge_frequency: 1, pledge_received: true)
      end

      it 'adds a notification if late' do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 65.days.ago)
        notifications = stopped_giving.check(contact.account_list)
        notifications.length.should == 1
      end

      it "doesn't add a notification if not late" do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 37.days.ago)
        notifications = stopped_giving.check(contact.account_list)
        notifications.length.should == 0
      end
    end

    context 'has never given' do
      it "doesn't add a notification" do
        notifications = stopped_giving.check(contact.account_list)
        notifications.length.should == 0
      end
    end
  end

  describe '.create_task' do
    let(:account_list) { create(:account_list) }

    it 'creates a task for the activity list' do
      expect {
        stopped_giving.create_task(account_list, contact.notifications.new)
      }.to change(Activity, :count).by(1)
    end

    it "associates the contact with the task created" do
      task = stopped_giving.create_task(account_list, contact.notifications.new)
      task.contacts.reload.should include contact
    end
  end
end
