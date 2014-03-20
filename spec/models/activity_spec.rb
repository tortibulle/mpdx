require 'spec_helper'

describe Activity do
  let(:account_list) { create(:account_list) }

  it "returns subject for to_s" do
    expect(Activity.new(subject: 'foo').to_s).to eq('foo')
  end

  describe "scope" do
    it "#overdue only includes uncompleted tasks" do
      history_task =  create(:task, account_list: account_list, start_at: Date.yesterday, completed: true)
      overdue_task = create(:task, account_list: account_list, start_at: Date.yesterday)
      today_task = create(:task, account_list: account_list, start_at: Time.now)

      overdue_tasks = account_list.tasks.overdue

      expect(overdue_tasks).to include overdue_task
      expect(overdue_tasks).not_to include history_task
      expect(overdue_tasks).not_to include today_task
    end

    it "#starred includes starred" do
      unstarred_task =  create(:task, account_list: account_list)
      starred_task = create(:task, account_list: account_list, starred: true)

      starred_tasks = account_list.tasks.starred

      expect(starred_tasks).to include starred_task
      expect(starred_tasks).not_to include unstarred_task
    end
  end

  context '#update_attributes' do
    it 'saves a task with a blank related contact' do
      task = create(:task)
      ac = task.activity_contacts.create!
      expect(
        task.update_attributes("subject"=>"zvxzcz", "start_at(2i)"=>"12", "start_at(3i)"=>"10", "start_at(1i)"=>"2013", "start_at(4i)"=>"15", "start_at(5i)"=>"15", "activity_type"=>"Call", "tag_list"=>"", "activity_comments_attributes"=>{"0"=>{"body"=>"asdf"}}, "activity_contacts_attributes"=>{"0"=>{"contact_id"=>"", "id"=>ac.id.to_s}})
      ).to be_true
    end
  end
end
