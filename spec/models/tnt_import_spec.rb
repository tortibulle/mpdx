require 'spec_helper'

describe TntImport do
  let(:xml) { import.read_xml(tnt_import.file.file.file) }
  let(:tnt_import) { create(:tnt_import, override: true) }
  let(:import) { TntImport.new(tnt_import) }
  let(:contact) { create(:contact) }
  let(:contact_rows) { Array.wrap(xml['Database']['Tables']['Contact']['row']) }
  let(:task_rows) { Array.wrap(xml['Database']['Tables']['Task']['row']) }
  let(:task_contact_rows) { Array.wrap(xml['Database']['Tables']['TaskContact']['row']) }
  let(:history_rows) { Array.wrap(xml['Database']['Tables']['History']['row']) }
  let(:history_contact_rows) { Array.wrap(xml['Database']['Tables']['HistoryContact']['row']) }
  let(:property_rows) { Array.wrap(xml['Database']['Tables']['Property']['row']) }

  before do
    stub_request(:get, /api\.smartystreets\.com\/.*/)
      .with(headers: { 'Accept' => 'application/json', 'Accept-Encoding' => 'gzip, deflate', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: '{}', headers: {})
  end

  context '#import_contacts' do
    it 'associates referrals' do
      import.should_receive(:add_or_update_donor_accounts).and_return([create(:donor_account)])
      import.should_receive(:add_or_update_donor_accounts).and_return([create(:donor_account)])
      expect {
        import.send(:import_contacts)
      }.to change(ContactReferral, :count).by(1)
    end

    context 'updating an existing contact' do
      before do
        account_list = create(:account_list)
        tnt_import.account_list = account_list
        tnt_import.save
        TntImport.new(tnt_import)
        contact.tnt_id = 1_620_699_916
        contact.status = 'Ask in Future'
        contact.account_list = account_list
        contact.save
      end

      it 'updates an existing contact' do
        import.should_receive(:add_or_update_donor_accounts).and_return([create(:donor_account)])
        import.should_receive(:add_or_update_donor_accounts).and_return([create(:donor_account)])
        expect {
          import.send(:import_contacts)
        }.to change { contact.reload.status }.from('Ask in Future').to('Partner - Pray')
      end

      it 'changes the primary address of an existing contact' do
        donor_account_one = create(:donor_account)
        donor_account_two = create(:donor_account)
        import.should_receive(:add_or_update_donor_accounts).and_return([donor_account_one])
        import.should_receive(:add_or_update_donor_accounts).and_return([donor_account_two])
        import.should_receive(:add_or_update_donor_accounts).and_return([donor_account_one])
        import.should_receive(:add_or_update_donor_accounts).and_return([donor_account_two])
        address = create(:address, primary_mailing_address: true)
        contact.addresses << address
        contact.save
        expect {
          import.send(:import_contacts)
        }.not_to change { contact.addresses.where(primary_mailing_address: true).count }
        expect { # make sure it survives a second import
          import.send(:import_contacts)
        }.not_to change { contact.addresses.where(primary_mailing_address: true).count }
      end
    end

    it 'imports a contact people details even if the contact is not a donor' do
      import = TntImport.new(create(:tnt_import_non_donor))
      expect {
        import.send(:import_contacts)
      }.to change(Person, :count).by(1)
    end
  end

  context '#update_contact' do
    it 'updates notes correctly' do
      contact = Contact.new
      import.send(:update_contact, contact, contact_rows.first)
      expect(contact.notes).to eq("Principal\nHas run into issues with Campus Crusade in the past...  Was told couldn't be involved because hadn't been baptized as an adult.")
    end

    it 'updates newsletter preferences correctly' do
      contact = Contact.new
      import.send(:update_contact, contact, contact_rows.first)
      expect(contact.send_newsletter).to eq('Physical')
    end
  end

  context '#update_person_attributes' do
    it 'imports a phone number for a person' do
      person = Person.new
      expect {
        person = import.send(:update_person_attributes, person, contact_rows.first)
      }.to change(person.phone_numbers, :length).by(2)
    end
  end

  context '#add_or_update_donor_accounts' do
    let(:organization) { create(:organization) }
    let(:designation_profile) { create(:designation_profile, organization: organization) }

    it 'finds an existing donor account' do
      create(:donor_account, organization: organization, account_number: contact_rows.first['OrgDonorCodes'])

      expect {
        import.send(:add_or_update_donor_accounts, contact_rows.first, designation_profile)
      }.not_to change(DonorAccount, :count)
    end

    it 'finds an existing contact' do
      tnt_import.account_list.contacts << create(:contact, name: contact_rows.first['FileAs'])
      tnt_import.account_list.save

      expect {
        import.send(:add_or_update_donor_accounts, contact_rows.first, designation_profile)
      }.not_to change(Contact, :count)
    end

    it 'creates a new donor account' do
      expect {
        import.send(:add_or_update_donor_accounts, contact_rows.first, designation_profile)
      }.to change(DonorAccount, :count).by(1)
    end

    it 'creates a new contact' do
      expect {
        import.send(:import_contacts)
      }.to change(Contact, :count).by(2)
    end

    it 'creates a new contact from a non-donor' do
      import = TntImport.new(create(:tnt_import_non_donor))
      expect {
        import.send(:import_contacts)
      }.to change(Contact, :count).by(1)
    end

    it "doesn't create duplicate people when importing the same list twice" do
      import = TntImport.new(create(:tnt_import_non_donor))
      import.send(:import_contacts)

      expect {
        import.send(:import_contacts)
      }.not_to change(Person, :count)
    end

  end

  context '#import_tasks' do
    it 'creates a new task' do
      expect {
        tasks = import.send(:import_tasks)
        tasks.first[1].remote_id.should_not be_nil
      }.to change(Task, :count).by(1)
    end

    it 'updates an existing task' do
      create(:task, source: 'tnt', remote_id: task_rows.first['id'], account_list: tnt_import.account_list)

      expect {
        import.send(:import_tasks)
      }.not_to change(Task, :count).by(1)
    end

    it 'accociates a contact with the task' do
      expect {
        import.send(:import_tasks,  task_contact_rows.first['ContactID'] => contact)
      }.to change(ActivityContact, :count).by(1)
    end

    it 'adds notes as a task comment' do
      task = create(:task, source: 'tnt', remote_id: task_rows.first['id'], account_list: tnt_import.account_list)

      import.send(:import_tasks)

      task.activity_comments.first.body.should == 'Notes'
    end
  end

  context '#import_history' do
    it 'creates a new completed task' do
      expect {
        tasks = import.send(:import_history)
        tasks.first[1].remote_id.should_not be_nil
      }.to change(Task, :count).by(1)
    end

    it 'marks an existing task as completed' do
      create(:task, source: 'tnt', remote_id: history_rows.first['id'], account_list: tnt_import.account_list)

      expect {
        import.send(:import_history)
      }.not_to change(Task, :count).by(1)
    end

    it 'accociates a contact with the task' do
      expect {
        import.send(:import_history,  history_contact_rows.first['ContactID'] => contact)
      }.to change(ActivityContact, :count).by(1)
    end

  end

  context '#import_settings' do
    it 'updates monthly goal' do
      import.should_receive(:create_or_update_mailchimp).and_return

      expect {
        import.send(:import_settings)
      }.to change(tnt_import.account_list, :monthly_goal).from(nil).to(6300)
    end
  end

  context '#create_or_update_mailchimp' do

    it 'creates a mailchimp account' do
      expect {
        import.send(:create_or_update_mailchimp, 'asdf', 'asasdfdf-us4')
      }.to change(MailChimpAccount, :count).by(1)
    end

    it 'updates a mailchimp account' do
      tnt_import.account_list.create_mail_chimp_account(api_key: '5', primary_list_id: '6')

      expect {
        import.send(:create_or_update_mailchimp, '1', '2')
      }.to change(tnt_import.account_list.mail_chimp_account, :api_key).from('5').to('2')
    end

  end

  context '#import' do
    it 'performs an import' do
      import.should_receive(:xml).and_return('foo')
      import.should_receive(:import_contacts).and_return
      import.should_receive(:import_tasks).and_return
      import.should_receive(:import_history).and_return
      import.should_receive(:import_settings).and_return
      import.import
    end
  end

end
