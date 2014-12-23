require 'spec_helper'

describe PeopleController do

  before(:each) do
    @user = create(:user_with_account)
    sign_in(:user, @user)
    @account_list = @user.account_lists.first
    @contact = create(:contact, account_list: @account_list)
  end

  def valid_attributes
    @valid_attributes ||= build(:person).attributes.except(*%w(id created_at updated_at sign_in_count current_sign_in_at
                                                               last_sign_in_at current_sign_in_ip last_sign_in_ip
                                                               master_person_id access_token))
  end

  describe 'GET show' do
    it 'assigns the requested person as @person' do
      person = @contact.people.create! valid_attributes
      get :show,  id: person.to_param
      assigns(:person).should eq(person)
    end
  end

  describe 'GET new' do
    it 'assigns a new person as @person' do
      get :new, {}
      assigns(:person).should be_a_new(Person)
    end
  end

  describe 'GET edit' do
    it 'assigns the requested person as @person' do
      person = @contact.people.create! valid_attributes
      get :edit,  id: person.to_param
      assigns(:person).should eq(person)
    end
  end

  describe 'POST create' do
    describe 'with valid params' do
      it 'creates a new Person' do
        expect {
          post :create,  contact_id: @contact.id, person: valid_attributes
        }.to change(Person, :count).by(1)
      end

      it 'creates a nested email' do
        expect {
          post :create,  contact_id: @contact.id, person: valid_attributes.merge('email_address' => { 'email' => 'john.doe@example.com' })
        }.to change(EmailAddress, :count).by(1)
        assigns(:person).email.to_s.should == 'john.doe@example.com'
      end

      it 'creates a nested phone number' do
        expect {
          post :create,  contact_id: @contact.id, person: valid_attributes.merge('phone_number' => { 'number' => '123-312-2134' })
        }.to change(PhoneNumber, :count).by(1)
        assigns(:person).phone_number.number.should == '+11233122134'
      end

      # it "creates a nested address" do
        # expect {
          # post :create, {contact_id: @contact.id, :person => valid_attributes.merge("addresses_attributes"=>{'0' => {"street"=>"boo"}})}
        # }.to change(Address, :count).by(1)
        # assigns(:person).address.street.should == "boo"
      # end

      it 'assigns a newly created person as @person' do
        post :create,  contact_id: @contact.id, person: valid_attributes
        assigns(:person).should be_a(Person)
        assigns(:person).should be_persisted
      end

      it 'redirects back to the contact' do
        post :create,  contact_id: @contact.id, person: valid_attributes
        response.should redirect_to(@contact)
      end
    end

    describe 'with invalid params' do
      it 'assigns a newly created but unsaved person as @person' do
        # Trigger the behavior that occurs when invalid params are submitted
        Person.any_instance.stub(:save).and_return(false)
        post :create,  contact_id: @contact.id, person: { first_name: '' }
        assigns(:person).should be_a_new(Person)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Person.any_instance.stub(:save).and_return(false)
        post :create,  contact_id: @contact.id, person: { first_name: '' }
        response.should render_template('new')
      end
    end
  end

  describe 'PUT update' do
    describe 'with valid params' do
      it 'updates the requested person' do
        person = @contact.people.create! valid_attributes
        # Assuming there are no other people in the database, this
        # specifies that the Person created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Person.any_instance.should_receive(:update_attributes).with('first_name' => 'params')
        put :update,  id: person.to_param, person: { 'first_name' => 'params' }
      end

      it 'assigns the requested person as @person' do
        person = @contact.people.create! valid_attributes
        put :update,  id: person.to_param, person: valid_attributes
        assigns(:person).should eq(person)
      end

      it 'redirects to the person' do
        person = @contact.people.create! valid_attributes
        put :update,  id: person.to_param, person: valid_attributes
        response.should redirect_to(person)
      end
    end

    describe 'with invalid params' do
      it 'assigns the person as @person' do
        person = @contact.people.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Person.any_instance.stub(:save).and_return(false)
        put :update,  id: person.to_param, person: { first_name: '' }
        assigns(:person).should eq(person)
      end

      it "re-renders the 'edit' template" do
        person = @contact.people.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Person.any_instance.stub(:save).and_return(false)
        put :update,  id: person.to_param, person: { first_name: '' }
        response.should render_template('edit')
      end
    end
  end

  describe 'DELETE destroy' do
    it 'destroys the requested person' do
      person = @contact.people.create! valid_attributes
      expect {
        delete :destroy,  id: person.to_param
      }.to change(Person, :count).by(-1)
    end

    it 'redirects to the people list' do
      person = @contact.people.create! valid_attributes
      delete :destroy,  id: person.to_param
      response.should redirect_to(people_url)
    end
  end

  describe 'PUT not_duplicates' do
    it 'adds the passed in ids to each persons not_duplicated_with field' do
      person1 = @contact.people.create! valid_attributes
      person2 = @contact.people.create! valid_attributes
      person3 = @contact.people.create! valid_attributes

      person1.update_column(:not_duplicated_with, person3.id.to_s)
      person2.update_column(:not_duplicated_with, person3.id.to_s)

      put :not_duplicates, ids: "#{person1.id},#{person2.id}", format: :js

      person1.reload
      person2.reload

      expect(person1.not_duplicated_with.split(',')).to include(person3.id.to_s)
      expect(person1.not_duplicated_with.split(',')).to include(person2.id.to_s)

      expect(person2.not_duplicated_with.split(',')).to include(person3.id.to_s)
      expect(person2.not_duplicated_with.split(',')).to include(person1.id.to_s)
    end
  end
end
