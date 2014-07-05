require 'spec_helper'

describe AccountList do

  context '.find_or_create_from_profile' do
    let(:org_account) { create(:organization_account) }
    let(:profile) { create(:designation_profile, user_id: org_account.person_id, organization: org_account.organization) }

    it 'should create a new account list if none is found' do
      da = create(:designation_account, organization: org_account.organization)
      profile.designation_accounts << da
      expect {
        AccountList.find_or_create_from_profile(profile, org_account)
      }.to change(AccountList, :count).by(1)
    end

    it 'should not create a new account list if one is found' do
      da = create(:designation_account, organization: org_account.organization)
      profile.designation_accounts << da
      account_list = create(:account_list)
      profile2 = create(:designation_profile, account_list: account_list)
      profile2.designation_accounts << da
      expect(AccountList.find_or_create_from_profile(profile, org_account))
          .to eq(account_list)
    end
  end

  context '#send_account_notifications' do
    it 'checks all notification types' do
      NotificationType.should_receive(:check_all)
      AccountList.new.send(:send_account_notifications)
    end
  end

  context '#valid_mail_chimp_account' do
    let(:account_list) { build(:account_list) }

    it 'returns true if there is a mailchimp associated with this account list that has a valid primary list' do
      mail_chimp_account = double(active?: true, primary_list: { id: 'foo', name: 'bar' })
      account_list.should_receive(:mail_chimp_account).twice.and_return(mail_chimp_account)
      account_list.valid_mail_chimp_account.should == true
    end

    it 'returns a non-true value when primary list is not present' do
      mail_chimp_account = double(active?: true, primary_list: nil)
      account_list.should_receive(:mail_chimp_account).twice.and_return(mail_chimp_account)
      account_list.valid_mail_chimp_account.should_not == true
    end

    it 'returns a non-true value when mail_chimp_account is not active' do
      mail_chimp_account = double(active?: false, primary_list: nil)
      account_list.should_receive(:mail_chimp_account).once.and_return(mail_chimp_account)
      account_list.valid_mail_chimp_account.should_not == true
    end

    it 'returns a non-true value when there is no mail_chimp_account' do
      account_list.should_receive(:mail_chimp_account).once.and_return(nil)
      account_list.valid_mail_chimp_account.should_not == true
    end

  end

  context '#top_partners' do
    let(:account_list) { create(:account_list) }

    it 'returns the top 10 donors on your list' do
      11.times do |i|
        account_list.contacts << create(:contact, total_donations: i)
      end

      account_list.top_partners.should == account_list.contacts.order(:id)[1..-1].reverse
    end
  end

  context '#people_with_birthdays' do
    let(:account_list) { create(:account_list) }
    let(:contact) { create(:contact) }
    let(:person) { create(:person, birthday_month: 8, birthday_day: 30) }

    before do
      contact.people << person
      account_list.contacts << contact
    end

    it 'handles a date range where the start and end day are in the same month' do
      account_list.people_with_birthdays(Date.new(2012, 8, 29), Date.new(2012, 8, 31)).should == [person]
    end

    it 'handles a date range where the start and end day are in different months' do
      account_list.people_with_birthdays(Date.new(2012, 8, 29), Date.new(2012, 9, 1)).should == [person]
    end

  end
  context '#people_with_anniversaries' do
    let(:account_list) { create(:account_list) }
    let(:contact) { create(:contact) }
    let(:person) { create(:person, anniversary_month: 8, anniversary_day: 30) }

    before do
      contact.people << person
      account_list.contacts << contact
    end

    it 'handles a date range where the start and end day are in the same month' do
      account_list.people_with_anniversaries(Date.new(2012, 8, 29), Date.new(2012, 8, 31)).should == [person]
    end

    it 'handles a date range where the start and end day are in different months' do
      account_list.people_with_anniversaries(Date.new(2012, 8, 29), Date.new(2012, 9, 1)).should == [person]
    end

  end

end
