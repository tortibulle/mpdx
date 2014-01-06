require 'spec_helper'

describe Person::OrganizationAccountsController do

  before(:each) do 
    @user = FactoryGirl.create(:user)
    sign_in(:user, @user)
    @org = FactoryGirl.create(:fake_org)

  end

  def valid_attributes
    @valid_attributes ||= { username: 'foo@example.com', password: 'foobar1', organization_id: @org.id }
  end
  


  #describe "GET index" do
    #it "assigns all person_organization_accounts as @person_organization_accounts" do
      #organization_account = Person::OrganizationAccount.create! valid_attributes
      #get :index, {}
      #assigns(:person_organization_accounts).should eq([organization_account])
    #end
  #end

  #describe "GET show" do
    #it "assigns the requested organization_account as @organization_account" do
      #organization_account = Person::OrganizationAccount.create! valid_attributes
      #get :show, {:id => organization_account.to_param}
      #assigns(:organization_account).should eq(organization_account)
    #end
  #end

  describe "GET new" do
    it "assigns a new organization_account as @organization_account" do
      org = FactoryGirl.create(:fake_org)
      xhr :get, :new, id: org.id
      assigns(:organization_account).should be_a_new(Person::OrganizationAccount)
      assigns(:organization).should == org
    end
  end

  #describe "GET edit" do
    #it "assigns the requested organization_account as @organization_account" do
      #organization_account = Person::OrganizationAccount.create! valid_attributes
      #get :edit, {:id => organization_account.to_param}
      #assigns(:organization_account).should eq(organization_account)
    #end
  #end

  describe "POST create" do
    before(:each) do
      #@org.stub(:api).and_return(FakeApi.new)
    end
    describe "with valid params" do
      it "creates a new Person::OrganizationAccount" do
        expect {
          xhr :post, :create, {:person_organization_account => valid_attributes}
        }.to change(Person::OrganizationAccount, :count).by(1)
      end

      it "assigns a newly created organization_account as @organization_account" do
        xhr :post, :create, {:person_organization_account => valid_attributes}
        assigns(:organization_account).should be_a(Person::OrganizationAccount)
        assigns(:organization_account).should be_persisted
      end

      it "redirects to the created organization_account" do
        xhr :post, :create, {:person_organization_account => valid_attributes}
        response.should render_template('create')
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved organization_account as @organization_account" do
        # Trigger the behavior that occurs when invalid params are submitted
        Person::OrganizationAccount.any_instance.stub(:save).and_return(false)
        xhr :post, :create, {:person_organization_account => {username: ''}}
        assigns(:organization_account).should be_a_new(Person::OrganizationAccount)
        response.should render_template("new")
      end
    end
  end

  #describe "PUT update" do
    #describe "with valid params" do
      #it "updates the requested organization_account" do
        #organization_account = Person::OrganizationAccount.create! valid_attributes
        ## Assuming there are no other person_organization_accounts in the database, this
        ## specifies that the Person::OrganizationAccount created on the previous line
        ## receives the :update_attributes message with whatever params are
        ## submitted in the request.
        #Person::OrganizationAccount.any_instance.should_receive(:update_attributes).with({'these' => 'params'})
        #put :update, {:id => organization_account.to_param, :organization_account => {'these' => 'params'}}
      #end

      #it "assigns the requested organization_account as @organization_account" do
        #organization_account = Person::OrganizationAccount.create! valid_attributes
        #put :update, {:id => organization_account.to_param, :organization_account => valid_attributes}
        #assigns(:organization_account).should eq(organization_account)
      #end

      #it "redirects to the organization_account" do
        #organization_account = Person::OrganizationAccount.create! valid_attributes
        #put :update, {:id => organization_account.to_param, :organization_account => valid_attributes}
        #response.should redirect_to(organization_account)
      #end
    #end

    #describe "with invalid params" do
      #it "assigns the organization_account as @organization_account" do
        #organization_account = Person::OrganizationAccount.create! valid_attributes
        ## Trigger the behavior that occurs when invalid params are submitted
        #Person::OrganizationAccount.any_instance.stub(:save).and_return(false)
        #put :update, {:id => organization_account.to_param, :organization_account => {}}
        #assigns(:organization_account).should eq(organization_account)
      #end

      #it "re-renders the 'edit' template" do
        #organization_account = Person::OrganizationAccount.create! valid_attributes
        ## Trigger the behavior that occurs when invalid params are submitted
        #Person::OrganizationAccount.any_instance.stub(:save).and_return(false)
        #put :update, {:id => organization_account.to_param, :organization_account => {}}
        #response.should render_template("edit")
      #end
    #end
  #end

  #describe "DELETE destroy" do
    #it "destroys the requested organization_account" do
      #organization_account = Person::OrganizationAccount.create! valid_attributes
      #expect {
        #delete :destroy, {:id => organization_account.to_param}
      #}.to change(Person::OrganizationAccount, :count).by(-1)
    #end

    #it "redirects to the person_organization_accounts list" do
      #organization_account = Person::OrganizationAccount.create! valid_attributes
      #delete :destroy, {:id => organization_account.to_param}
      #response.should redirect_to(person_organization_accounts_url)
    #end
  #end

end
