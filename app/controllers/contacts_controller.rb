class ContactsController < ApplicationController
  respond_to :html, :js
  before_filter :get_contact, only: [:show, :edit, :update]
  before_filter :get_contacts, only: [:show, :index]

  def index
    @contacts = @contacts.includes(:people, :tags).order('contacts.name')
    if params[:filter] == 'people'
      @contacts = @contacts.people
    end

    if params[:filter] == 'companies'
      @contacts = @contacts.companies
    end

    if params[:tags].present?
      @tags = params[:tags].split(',')
      @contacts = @contacts.tagged_with(@tags)
    end

    if params[:city].present? && params[:city].first != ''
      @contacts = @contacts.includes(:addresses).where('addresses.city' => params[:city])
    end

    if params[:state].present? && params[:state].first != ''
      @contacts = @contacts.includes(:addresses).where('addresses.state' => params[:state])
    end

    if params[:newsletter]
      @contacts = @contacts.where('send_newsletter is not null')
      case params[:newsletter]
      when 'address'
        @contacts = @contacts.joins(:addresses).where('street is not null')
      when 'email'
        @contacts = @contacts.joins(people: :email_addresses)
        @contacts = @contacts.uniq unless @contacts.to_sql.include?('"addresses"')
      end
    end

    respond_to do |wants|
      wants.html do
        @contacts = @contacts.page(params[:page])
      end
      wants.csv do
        @headers = ['Full Name','Greeting','Mailing Street Address','Mailing City',
                    'Mailing State','Mailing Postal Code', 'Mailing Country',
                    'Email 1','Email 2','Email 3','Email 4']
        render_csv("contacts-#{Time.now.strftime("%Y%m%d")}")
      end
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
