require 'spec_helper'

describe ContactsController do
  describe 'when signed in' do
    let(:user) { create(:user_with_account) }
    let!(:contact) { create(:contact, account_list: user.account_lists.first) }

    before(:each) do
      sign_in(:user, user)
    end

    describe '#index' do
      let(:contact2) { create(:contact, name: 'Z', account_list: user.account_lists.first) }

      before do
        donor_account = create(:donor_account, master_company: create(:master_company))
        contact2.donor_accounts << donor_account
      end

      it "gets all" do
        get :index
        response.should be_success
        assigns(:contacts).length.should.should == 2
      end

      it "filters out people you don't want to contact even when no filter is set" do
        contact.update_attributes(status: 'Not Interested')
        get :index
        response.should be_success
        assigns(:contacts).length.should == 1
      end


      it "gets people" do
        get :index, filter: 'people'
        response.should be_success
        assigns(:contacts).should == [contact]
      end

      it "gets companies" do
        get :index, filter: 'companies'
        response.should be_success
        assigns(:contacts).should == [contact2]
      end

      it "filters by tag" do
        contact.update_attributes(tag_list: 'asdf')
        get :index, filters: {tags: 'asdf'}
        response.should be_success
        assigns(:contacts).should == [contact]
      end

      it "doesn't display duplicate rows when filtering by Newsletter Recipients With Mailing Address" do
        contact.update_attributes(send_newsletter: 'Physical')
        2.times do
          contact.addresses << create(:address, addressable: contact)
        end

        get :index, filters: {newsletter: 'address'}
        assigns(:contacts).length.should == 1
      end

      it "doesn't display duplicate rows when filtering by Newsletter Recipients With Email Address" do
        contact.update_attributes(send_newsletter: 'Email')
        p = create(:person)
        contact.people << p
        2.times do
          create(:email_address, person: p)
        end

        get :index, filters: {newsletter: 'email'}
        assigns(:contacts).length.should == 1
      end
    end

    describe '#show' do
      it "should find a contact in the current account list" do
        get :show, id: contact.id
        response.should be_success
        contact.should == assigns(:contact)
      end
    end

    describe '#edit' do
      it "should edit a contact in the current account list" do
        get :edit, id: contact.id
        response.should be_success
        contact.should == assigns(:contact)
      end
    end

    describe '#new' do
      it "should render the new template" do
        get :new
        response.should be_success
        response.should render_template('new')
      end
    end

    describe "#create" do
      it "should create a good record" do
        -> {
          post :create, contact: {name: 'foo'}
          contact = assigns(:contact)
          contact.errors.full_messages.should == []
          response.should redirect_to(contact)
        }.should change(Contact, :count).by(1)
      end

      it "doesn't create a contact without a name" do
        post :create, contact: {name: ''}
        assigns(:contact).errors.full_messages.should == ["Name can't be blank"]
        response.should be_success
      end

    end

    describe "#update" do
      it "updates a contact when passed valid attributes" do
        put :update, id: contact.id, contact: {name: 'Bob'}
        contact = assigns(:contact)
        contact.name.should == 'Bob'
        response.should redirect_to(contact)
      end

      it "doesn't update a contact when passed invalid attributes" do
        put :update, id: contact.id, contact: {name: ''}
        assigns(:contact).errors.full_messages.should == ["Name can't be blank"]
        response.should be_success
      end
    end

    describe "#destroy" do
      it "should hide a contact" do
        contact # instantiate object
        delete :destroy, id: contact.id

        contact.reload.status.should == 'Never Ask'
      end
    end

    describe '#bulk_update' do
      it "doesn't error out when all the attributes to update are blank" do
        xhr :put, :bulk_update, bulk_edit_contact_ids: '1', contact: {send_newsletter: ''}
        response.should be_success
      end
    end


  end
end
