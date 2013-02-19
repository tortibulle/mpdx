class PeopleController < ApplicationController
  respond_to :html, :js
  before_filter :get_contact
  before_filter :get_person, only: [:show, :edit, :update, :social_search]

  def show
    @person = current_account_list.people.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @person = Person.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def edit
  end

  def create
    @contact = current_account_list.contacts.find(params[:contact_id])
    Person.transaction do
      @person = @contact.people.new(params[:person])

      respond_to do |format|
        if @person.save
          format.html { redirect_to @contact }
        else
          format.html { render action: "new" }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @person.update_attributes(params[:person])
        format.html { redirect_to @person }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @person = current_account_list.people.find(params[:id])
    @person.destroy

    respond_to do |format|
      format.html { redirect_to people_path }
    end
  end

  private

  def get_person
    @person = current_account_list.people.find(params[:id])
  end

  def get_contact
    @contact = current_account_list.contacts.find(params[:contact_id]) if params[:contact_id]
  end
end
