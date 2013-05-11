require 'spec_helper'

describe NotificationType::SpecialGift do
  let!(:special_gift) { NotificationType::SpecialGift.first_or_initialize }
  let!(:da) { create(:designation_account_with_special_donor) }
  let(:contact) { da.contacts.non_financial_partners.first }
  let(:donation) { create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 5.days.ago) }

  context '#check' do

    it 'adds a notification if a gift comes from a non financial partner' do
      donation # create donation object from let above
      notifications = special_gift.check(da)
      notifications.length.should == 1
    end

    it "doesn't add a notification if first gift came more than 2 weeks ago" do
      create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 37.days.ago)
      notifications = special_gift.check(da)
      notifications.length.should == 0
    end

  end

  describe '.create_task' do
    let(:account_list) { create(:account_list) }

    it 'creates a task for the activity list' do
      expect {
        special_gift.create_task(account_list, contact.notifications.new(donation_id: donation.id))
      }.to change(Activity, :count).by(1)
    end

    it "associates the contact with the task created" do
      task = special_gift.create_task(account_list, contact.notifications.new(donation_id: donation.id))
      task.contacts.should include contact
    end
  end
end
