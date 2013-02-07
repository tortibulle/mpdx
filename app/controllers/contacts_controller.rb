class ContactsController < ApplicationController
  respond_to :html, :js
  before_filter :get_contact, only: [:show, :edit, :update, :add_referrals, :save_referrals, :details]
  before_filter :setup_filters, only: :index

  def index
    @contacts = current_account_list.contacts.order('contacts.name')

    if params[:filter] == 'people'
      @contacts = @contacts.people
    end

    if params[:filter] == 'companies'
      @contacts = @contacts.companies
    end

    @contacts = ContactFilter.new(filters_params).filter(@contacts) if filters_params.present?
    respond_to do |wants|

      wants.html do
        @contacts = @contacts.includes([{primary_person: :facebook_account}, :tags, :primary_address, {people: :primary_phone_number}])

        @contacts = @contacts.page(page).per_page(per_page)
      end

      wants.csv do
        @contacts = @contacts.includes(:primary_person, :spouse, :primary_address, :addresses, {people: :email_addresses})
        @headers = ['Contact Name', 'First Name', 'Last Name', 'Spouse First Name', 'Greeting',
                    'Mailing Street Address','Mailing City', 'Mailing State','Mailing Postal Code',
                    'Mailing Country', 'Email 1','Email 2','Email 3','Email 4']

        render_csv("contacts-#{Time.now.strftime("%Y%m%d")}")
      end

    end
  end

  def show
    respond_with(@contact)
  end

  def details
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
      begin
        if @contact.update_attributes(params[:contact])
          format.html { redirect_to @contact }
          format.js
        else
          format.html { render action: "edit" }
          format.js { render nothing: true }
        end
      rescue Errors::FacebookLink => e
        flash.now[:alert] = e.message
        format.html { render action: "edit" }
        format.js { render nothing: true }
      end
    end
  end

  def bulk_update
    contacts = current_account_list.contacts.where(id: params[:bulk_edit_contact_ids].split(','))
    attributes_to_update = params[:contact].select { |_, v| v.present? }
    if attributes_to_update.present?
      contacts.update_all(attributes_to_update)
      # Since update_all doesn't trigger callbacks, we need to manually sync with mail chimp
      if params[:contact][:send_newsletter].present? && (mail_chimp_account = current_account_list.mail_chimp_account)
        if %w[Email Both].include?(params[:contact][:send_newsletter])
          contacts.map { |c| mail_chimp_account.queue_subscribe_contact(c) }
        else
          contacts.map { |c| mail_chimp_account.queue_unsubscribe_contact(c) }
        end
      end
    end
  end

  def merge
    if params[:merge_contact_ids]
      params[:merge_sets] = [params[:merge_contact_ids]]
    end

    merged_contacts_count = 0

    params[:merge_sets].each do |ids|
      # When performing a merge we want to keep the contact with the most people
      contacts = current_account_list.contacts.includes(:people).where(id: ids.split(','))
      if contacts.length > 1
        merged_contacts_count += contacts.length
        winner = contacts.max_by {|c| c.people.length}
        Contact.transaction do
          (contacts - [winner]).each do |loser|
            winner.merge(loser)
          end
        end
      end
    end
    redirect_to contacts_path, notice: _('You just merged %{count} contacts') % {count: merged_contacts_count}
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

  def save_referrals
    @contacts = []
    @bad_contacts_count = 0
    Contact.transaction do
      params[:account_list][:contacts_attributes].each do |_, attributes|
        next if attributes.all? { |_, v| v.blank? }
        # create the new contact
        if attributes[:first_name].present? || attributes[:last_name].present?
          attributes[:first_name] = _('Unknown') if attributes[:first_name].blank?
          attributes[:last_name] = _('Unknown') if attributes[:last_name].blank?
          contact_name = "#{attributes[:last_name]}, #{attributes[:first_name]}"
          contact_name += " & #{attributes[:spouse_name]}" if attributes[:spouse_name].present?
          contact = current_account_list.contacts.create(name: contact_name)

          # create primary
          person = Person.create(attributes.slice(:first_name, :last_name, :email, :phone))
          contact.people << person

          # create spouse
          if attributes[:spouse_name].present?
            spouse = Person.create(first_name: attributes[:spouse_name], last_name: attributes[:last_name])
            contact.people << spouse
          end

          # create address
          contact.addresses_attributes = [attributes.slice(:street, :city, :state, :postal_code)]

          contact.save

          @contact.referrals_by_me << contact

          @contacts << contact

        else
          @bad_contacts_count += 1
        end

      end

      if @contacts.length > 0
        flash[:notice] = _("You have successfully added %{contacts_count:referrals}.").to_str.localize %
          { contacts_count: @contacts.length, referrals: { one: _('1 referral'), other: _('%{contacts_count} referrals') } }
      end

      if @bad_contacts_count > 0
        flash[:alert] = _("%{contacts_count:referrals} couldn't be added because they were missing the first and last name.").to_str.localize %
          { contacts_count: @bad_contacts_count, referrals: { one: _('1 referral'), other: _('%{contacts_count} referrals') } }

      end
    end
  end

  def find_duplicates
    respond_to do |wants|
      wants.html {  }
      wants.js do
        # Find sets of people with the same name
        people_with_duplicate_names = Person.connection.select_values("select array_to_string(array_agg(people.id), ',') from people INNER JOIN contact_people ON people.id = contact_people.person_id INNER JOIN contacts ON contact_people.contact_id = contacts.id WHERE contacts.account_list_id = #{current_account_list.id} group by first_name, last_name having count(*) > 1")
        @contact_sets = []
        contacts_checked = []
        people_with_duplicate_names.each do |pair|
          contacts = current_account_list.contacts.includes(:people).where('people.id' => pair.split(','))
          if contacts.length > 1
            already_included = false
            contacts.each { |c| already_included = true if contacts_checked.include?(c) }
            next if already_included
            contacts_checked += contacts
            @contact_sets << contacts
          end
        end
        @contact_sets.sort_by! { |s| s.first.name }
      end
    end
  end


  private

  def get_contact
    @contact = current_account_list.contacts.includes({people: [:primary_email_address, :primary_phone_number, :email_addresses, :phone_numbers, :family_relationships]}).find(params[:id])
  end

  def setup_filters
    current_user.contacts_filter ||= {}
    if filters_params.present?
      current_user.contacts_filter[current_account_list.id] = filters_params
    elsif params[:clear_filter] == 'true'
      current_user.contacts_filter[current_account_list.id] = nil
    end

    if current_user.contacts_filter.present? && current_user.contacts_filter[current_account_list.id].present?
      @filters_params = current_user.contacts_filter[current_account_list.id]
    end
  end

end
