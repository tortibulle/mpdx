require 'spec_helper'

describe TntImport do
  let(:tnt_import) { create(:tnt_import, override: true) }
  let(:import) { TntImport.new(tnt_import) }
  let(:contact) { create(:contact) }
  let(:contact_rows) { Array.wrap(import.read_xml(tnt_import.file.file.file)['Database']['Tables']['Contact']['row']) }
  let(:task_rows) { Array.wrap(import.read_xml(tnt_import.file.file.file)['Database']['Tables']['Task']['row']) }
  let(:task_contact_rows) { Array.wrap(import.read_xml(tnt_import.file.file.file)['Database']['Tables']['TaskContact']['row']) }
  let(:history_rows) { Array.wrap(import.read_xml(tnt_import.file.file.file)['Database']['Tables']['History']['row']) }
  let(:history_contact_rows) { Array.wrap(import.read_xml(tnt_import.file.file.file)['Database']['Tables']['HistoryContact']['row']) }
  let(:property_rows) { Array.wrap(import.read_xml(tnt_import.file.file.file)['Database']['Tables']['Property']['row']) }

  context '#import_contacts' do
    it 'associates referrals' do
      import.should_receive(:add_or_update_donor_accounts).and_return([[create(:donor_account)], contact])
      import.should_receive(:add_or_update_donor_accounts).and_return([[create(:donor_account)], create(:contact, name: 'Foo')])
      expect {
        import.send(:import_contacts)
      }.to change(ContactReferral, :count).by(1)
    end
  end

  context '#update_person_attributes' do
    it "imports a phone number for a person" do
      person = Person.new
      expect {
        person = import.send(:update_person_attributes, person, contact_rows.first)
      }.to change(person.phone_numbers, :length).by(1)
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
        import.send(:add_or_update_donor_accounts, contact_rows.first, designation_profile)
      }.to change(Contact, :count).by(1)
    end

  end

  context '#import_tasks' do
    it 'creates a new task' do
      expect {
        tasks = import.send(:import_tasks)
        tasks.first[1].tnt_id.should_not be_nil
      }.to change(Task, :count).by(1)
    end

    it 'updates an existing task' do
      create(:task, tnt_id: task_rows.first['id'], account_list: tnt_import.account_list)

      expect {
        import.send(:import_tasks)
      }.not_to change(Task, :count).by(1)
    end

    it 'accociates a contact with the task' do
      expect {
        import.send(:import_tasks, {task_contact_rows.first['ContactID'] => contact})
      }.to change(ActivityContact, :count).by(1)
    end
  end

  context '#import_history' do
    it 'creates a new completed task' do
      expect {
        tasks = import.send(:import_history)
        tasks.first[1].tnt_id.should_not be_nil
      }.to change(Task, :count).by(1)
    end

    it 'marks an existing task as completed' do
      create(:task, tnt_id: history_rows.first['id'], account_list: tnt_import.account_list)

      expect {
        import.send(:import_history)
      }.not_to change(Task, :count).by(1)
    end

    it 'accociates a contact with the task' do
      expect {
        import.send(:import_history, {history_contact_rows.first['ContactID'] => contact})
      }.to change(ActivityContact, :count).by(1)
    end

  end

  context '#import_settings' do
    it "updates monthly goal" do
      import.should_receive(:create_or_update_mailchimp).and_return

      expect {
        import.send(:import_settings)
      }.to change(tnt_import.account_list, :monthly_goal).from(nil).to(6300)
    end
  end

  context '#create_or_update_mailchimp' do

    it 'creates a mailchimp account' do
      expect {
        import.send(:create_or_update_mailchimp, '1', '2')
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
