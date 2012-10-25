require 'spec_helper'

describe ContactsController do
  describe 'when signed in' do
    before(:each) do
      @user = create(:user_with_account)
      sign_in(:user, @user)
      @contact = create(:contact, account_list: @user.account_lists.first)
    end

    describe 'GET index' do
      before do
        donor_account = create(:donor_account, master_company: create(:master_company))
        @contact2 = create(:contact, name: 'Z', account_list: @user.account_lists.first)
        @contact2.donor_accounts << donor_account
      end
      it "should get all" do
        get :index
        response.should be_success
        assigns(:contacts).should == [@contact, @contact2]
      end

      it "should get people" do
        get :index, filter: 'people'
        response.should be_success
        assigns(:contacts).should == [@contact]
      end

      it "should get companies" do
        get :index, filter: 'companies'
        response.should be_success
        assigns(:contacts).should == [@contact2]
      end

      it "should filter by tag" do
        @contact.update_attributes(tag_list: 'asdf')
        get :index, tags: 'asdf'
        response.should be_success
        assigns(:all_contacts).should == [@contact]
      end

    end

    describe 'GET show' do
      it "should find a contact in the current account list" do
        get :show, id: @contact.id
        response.should be_success
        @contact.should == assigns(:contact)
      end
    end

    describe 'GET edit' do
      it "should edit a contact in the current account list" do
        get :edit, id: @contact.id
        response.should be_success
        @contact.should == assigns(:contact)
      end
    end

    describe 'GET new' do
      it "should render the new template" do
        get :new
        response.should be_success
        response.should render_template('new')
      end
    end

    describe "POST 'create'" do
      it "should create a good record" do
        -> {
          post :create, contact: {name: 'foo'}
          contact = assigns(:contact)
          contact.errors.full_messages.should == []
          response.should redirect_to(contact)
        }.should change(Contact, :count).by(1)
      end

      it "should not create a contact without a name" do
        post :create, contact: {name: ''}
        assigns(:contact).errors.full_messages.should == ["Name can't be blank"]
        response.should be_success
      end

    end

    describe "PUT 'update'" do
      it "should update a contact valid" do
        put :update, id: @contact.id, contact: {name: 'Bob'}
        contact = assigns(:contact)
        contact.name.should == 'Bob'
        response.should redirect_to(contact)
      end

      it "should not update an invalid contact" do
        put :update, id: @contact.id, contact: {name: ''}
        assigns(:contact).errors.full_messages.should == ["Name can't be blank"]
        response.should be_success
      end
    end

    describe "GET 'destroy'" do
      it "should destroy a contact" do
        -> {
          delete :destroy, id: @contact.id
        }.should change(Contact, :count).by(-1)
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
