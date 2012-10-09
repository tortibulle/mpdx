class ContactsController < ApplicationController
  respond_to :html, :js
  before_filter :get_contact, only: [:show, :edit, :update]

  def index
    @contacts = current_account_list.contacts.order('contacts.name')

    @contacts = @contacts.includes({people: :facebook_account}, :tags)
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

    if params[:likely].present? && params[:likely].first != ''
      @contacts = @contacts.where(likely_to_give: params[:likely])
    end

    if params[:status].present? && params[:status].first != ''
      @contacts = @contacts.where(status: params[:status])
    end

    if params[:newsletter].present?
      case params[:newsletter]
      when 'address'
        @contacts = @contacts.where(send_newsletter: 'Physical')
        @contacts = @contacts.joins(:addresses).where('street is not null')
      when 'email'
        @contacts = @contacts.where(send_newsletter: 'Email')
        @contacts = @contacts.joins(people: :email_addresses)
        @contacts = @contacts.uniq unless @contacts.to_sql.include?('INNER JOIN')
      else
        @contacts = @contacts.where('send_newsletter is not null')
      end
    end

    respond_to do |wants|
      wants.html do
        @all_contacts = @contacts.select(['contacts.id', 'contacts.name'])
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
    @all_contacts = current_account_list.contacts.order('contacts.name').select([:id, :name])
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

  def bulk_update
    contacts = current_account_list.contacts.where(id: params[:bulk_edit_contact_ids].split(','))
    contacts.update_all(params[:contact].select { |_, v| v.present? })
    # Since update_all doesn't trigger callbacks, we need to manually sync with mail chimp
    if params[:contact][:send_newsletter].present? && (mail_chimp_account = current_account_list.mail_chimp_account)
      if params[:contact][:send_newsletter] == 'Physical'
        contacts.map { |c| mail_chimp_account.queue_unsubscribe_contact(c) }
      else
        contacts.map { |c| mail_chimp_account.queue_subscribe_contact(c) }
      end
    end
  end


  def merge
    # When performing a merge we want to keep the contact with the most people
    contacts = current_account_list.contacts.includes(:people).
               where(id: params[:merge_contact_ids].split(','))
    if contacts.length > 1
      winner = contacts.max_by {|c| c.people.length}
      Contact.transaction do
        (contacts - [winner]).each do |loser|
          winner.merge(loser)
        end
      end
    end
    redirect_to :back
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

  def add_referrals
    
  end

  protected
  def get_contact
    @contact = current_account_list.contacts.includes({people: [:email_addresses, :phone_numbers, :family_relationships]}).find(params[:id])
  end

end
