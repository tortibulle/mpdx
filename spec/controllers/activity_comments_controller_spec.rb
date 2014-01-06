require 'spec_helper'

describe ActivityCommentsController do
  let(:user) { create(:user_with_account) }
  let(:valid_attributes) { { body: 'baz' } }
  let(:activity) { create(:activity, account_list: user.account_lists.first) }

  before do
    sign_in(:user, user)
  end

  context '#create' do
    it 'saves a valid submission' do
      xhr :post, :create, activity_comment: valid_attributes, activity_id: activity.id

      response.should render_template('activity_comments/create')
    end

  end
end
