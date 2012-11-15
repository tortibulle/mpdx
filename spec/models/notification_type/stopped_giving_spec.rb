require 'spec_helper'

describe NotificationType::StoppedGiving do
  let!(:stopped_giving) { NotificationType::StoppedGiving.first_or_initialize }
  let!(:da) { create(:designation_account_with_donor) }
  let(:contact) { da.contacts.financial_partners.first }

  describe '.process' do
    context 'direct deposit donor' do
      before { contact.update_column(:direct_deposit, true) }

      it 'adds a notification if late' do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 38.days.ago)
        stopped_giving.should_receive(:add_notification)
        stopped_giving.process(da)
      end

      it "doesn't add a notification if not late" do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 37.days.ago)
        stopped_giving.should_not_receive(:add_notification)
        stopped_giving.process(da)
      end
    end

    context 'non-direct deposit donor' do
      before { contact.update_column(:pledge_frequency, 1) }

      it 'adds a notification if late' do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 61.days.ago)
        stopped_giving.should_receive(:add_notification)
        stopped_giving.process(da)
      end

      it "doesn't add a notification if not late" do
        create(:donation, donor_account: contact.donor_accounts.first, designation_account: da, donation_date: 37.days.ago)
        stopped_giving.should_not_receive(:add_notification)
        stopped_giving.process(da)
      end
    end
  end
end
