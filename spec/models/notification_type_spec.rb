require 'spec_helper'

describe NotificationType do

  context '.check_all' do
    let(:account_list) { create(:account_list) }
    let(:designation_account) { create(:designation_account) }
    let!(:special_gift) { NotificationType::SpecialGift.create! }

    it "checks for notifications of each type" do
      create(:notification_preference, account_list: account_list, notification_type: special_gift)
      NotificationType.should_receive(:types).and_return(['NotificationType::SpecialGift'])
      NotificationType::SpecialGift.should_receive(:first).and_return(special_gift)
      special_gift.should_receive(:check).and_return

      NotificationType.check_all(designation_account, account_list)
    end
  end

end
