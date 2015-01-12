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

  context '#users_combined_name' do
    let(:account_list) { create(:account_list, name: 'account list') }

    it 'combines first and second user names and gives account list name if no uers' do
      {
        [] => 'account list',
        [{ first_name: 'John' }] => 'John',
        [{ first_name: 'John', last_name: 'Doe' }] => 'John Doe',
        [{ first_name: 'John', last_name: 'Doe' }, { first_name: 'Jane', last_name: 'Doe' }] => 'John and Jane Doe',
        [{ first_name: 'John', last_name: 'A' }, { first_name: 'Jane', last_name: 'B' }] => 'John A and Jane B',
        [{ first_name: 'John' }, { first_name: 'Jane' }, { first_name: 'Paul' }] => 'John and Jane'
      }.each do |people_attrs, name|
        Person.destroy_all
        people_attrs.each do |person_attrs|
          account_list.users << create(:user, person_attrs)
        end
        expect(account_list.users_combined_name).to eq(name)
      end
    end
  end

  context '#physical_newsletter_csv' do
    it 'does not cause an error or give an empty string' do
      contact = create(:contact, name: 'Doe, John', send_newsletter: 'Both')
      contact.addresses << create(:address)
      account_list = create(:account_list)
      account_list.contacts << contact

      csv_rows = CSV.parse(account_list.physical_newsletter_csv)
      expect(csv_rows.size).to eq(3)
      csv_rows.each_with_index do |row, index|
        expect(row[0]).to eq('Contact Name') if index == 0
        expect(row[0]).to eq('Doe, John') if index == 1
        expect(row[0]).to be_nil if index == 2
      end
    end
  end

  context '#user_emails_with_names' do
    let(:account_list) { create(:account_list) }

    it 'handles the no users case and no email fine' do
      expect(account_list.user_emails_with_names).to be_empty
      account_list.users << create(:user)
      expect(account_list.user_emails_with_names).to be_empty
    end

    it 'gives the names of the users with the email addresses' do
      user1 = create(:user, first_name: 'John')
      user1.email = 'john@a.com'
      user1.save
      user2 = create(:user, first_name: 'Jane', last_name: 'Doe')
      user2.email = 'jane@a.com'
      user2.save
      user3 = create(:user)

      account_list.users << user1
      expect(account_list.user_emails_with_names.first).to eq('John <john@a.com>')

      account_list.users << user2
      account_list.users << user3
      expect(account_list.user_emails_with_names.size).to eq(2)
      expect(account_list.user_emails_with_names).to include('John <john@a.com>')
      expect(account_list.user_emails_with_names).to include('Jane Doe <jane@a.com>')
    end
  end
end
