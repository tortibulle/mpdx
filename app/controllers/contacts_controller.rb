class ContactsController < ApplicationController
  respond_to :html, :js
  before_filter :get_contact, only: [:show, :edit, :update]
  before_filter :get_contacts, only: [:show, :index]

  def index
    @contacts = @contacts.includes(:people).order('contacts.name')
    if params[:filter] == 'people'
      @contacts = @contacts.people
    end

    if params[:filter] == 'companies'
      @contacts = @contacts.companies
    end
  end

  def show
    @contacts = @contacts.all
    respond_with(@contact)
  end

  def new
    @contact = current_account_list.contacts.new
  end

  def edit
  end

  def create
    Contact.transaction do
      @contact = current_account_list.contacts.new(params[:contact])

      respond_to do |format|
        if @contact.save
          format.html { redirect_to @contact }
        else
          format.html { render action: "new" }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @contact.update_attributes(params[:contact])
        format.html { redirect_to @contact }
        format.js
      else
        format.html { render action: "edit" }
        format.js { render nothing: true }
      end
    end
  end

  def destroy
    @contact = current_account_list.contacts.find(params[:id])
    @contact.destroy

    respond_to do |format|
      format.html { redirect_to contacts_path }
    end
  end

  def social_search
    render nothing: true and return unless %[facebook twitter linkedin].include?(params[:network])
    @results = "Person::#{params[:network].titleize}Account".constantize.search(current_user, params)
    render layout: false
  end

  protected
  def get_contact
    @contact = current_account_list.contacts.includes({people: [:email_addresses, :phone_numbers, :family_relationships]}).find(params[:id])
  end

  def get_contacts
    @contacts = current_account_list.contacts.order('contacts.name')
  end
end
