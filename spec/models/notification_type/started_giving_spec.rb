require 'spec_helper'

describe NotificationType::StartedGiving do
  let!(:started_giving) { NotificationType::StartedGiving.first_or_initialize }
  let!(:da) { create(:designation_account_with_donor) }
  let(:contact) { da.contacts.financial_partners.first }

  context '#check' do
    before { contact.update_column(:direct_deposit, true) }

    it 'adds a notification if first gift came within past 2 weeks' do
      create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 5.days.ago)
      notifications = started_giving.check(da)
      notifications.length.should == 1
    end

    it "doesn't add a notification if not first gift" do
      2.times do |i|
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: (i * 30).days.ago)
      end
      notifications = started_giving.check(da)
      notifications.length.should == 0
    end

    it "doesn't add a notification if first gift came more than 2 weeks ago" do
      create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 37.days.ago)
      notifications = started_giving.check(da)
      notifications.length.should == 0
    end

  end

  describe '.create_task' do
    let(:account_list) { create(:account_list) }

    it 'creates a task for the activity list' do
      expect {
        started_giving.create_task(account_list, contact.notifications.new)
      }.to change(Activity, :count).by(1)
    end

    it "associates the contact with the task created" do
      task = started_giving.create_task(account_list, contact.notifications.new)
      task.contacts.reload.should include contact
    end
  end
end
