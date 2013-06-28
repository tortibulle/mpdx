class ContactsController < ApplicationController
  respond_to :html, :js
  before_filter :get_contact, only: [:show, :edit, :update, :add_referrals, :save_referrals, :details]
  before_filter :setup_filters, only: [:index, :show]

  def index
    if params[:filters] && params[:filters][:name].present?
      contacts_with_name = ContactFilter.new({name: filters_params[:name], status: ['*']}).filter(current_account_list.contacts)
      if contacts_with_name.count == 1
        current_user.contacts_filter[current_account_list.id].delete("name")
        current_user.save
        redirect_to contacts_with_name.first
        return
      end
    end

    @page_title = _('Contacts')

    @filtered_contacts = filtered_contacts

    respond_to do |wants|

      wants.html do
        @contacts = @filtered_contacts.includes([{primary_person: :facebook_account},
                                                 :tags, :primary_address,
                                                 {people: :primary_phone_number}])
                                      .page(page)
                                      .per_page(per_page)
      end

      wants.csv do
        @contacts = @filtered_contacts.includes(:primary_person, :spouse, :primary_address, {people: :email_addresses})
        @headers = ['Contact Name', 'First Name', 'Last Name', 'Spouse First Name', 'Greeting',
                    'Mailing Street Address','Mailing City', 'Mailing State','Mailing Postal Code',
                    'Mailing Country', 'Email 1','Email 2','Email 3','Email 4']

        render_csv("contacts-#{Time.now.strftime("%Y%m%d")}")
      end

    end
  end

  def show
    @page_title = @contact.name

    @filtered_contacts = filtered_contacts

    respond_with(@contact)
  end

  def details
    respond_with(@contact)
  end

  def new
    @page_title = _('New Contact')

    @contact = current_account_list.contacts.new
  end

  def edit
    @page_title = _('Edit - %{contact}') % {contact: @contact.name}
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
    @page_title = _('Merge Contacts')

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
    end if params[:merge_sets].present?
    redirect_to :back, notice: _('You just merged %{count} contacts') % {count: merged_contacts_count}
  end

  def destroy
    @contact = current_account_list.contacts.find(params[:id])
    @contact.hide

    respond_to do |format|
      format.html { redirect_to contacts_path }
      format.js { render nothing: true }
    end
  end

  def bulk_destroy
    @contacts = current_account_list.contacts.find(params[:ids])
    @contacts.map(&:hide)

    respond_to do |format|
      format.html { redirect_to contacts_path }
      format.js { render nothing: true }
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

          begin
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
          rescue ActiveRecord::RecordInvalid
            @bad_contacts_count += 1
          end
        else
          @bad_contacts_count += 1
        end

      end

      if @contacts.length > 0
        flash[:notice] = _("You have successfully added %{contacts_count:referrals}.").to_str.localize %
          { contacts_count: @contacts.length, referrals: { one: _('1 referral'), other: _('%{contacts_count} referrals') } }
      end

      if @bad_contacts_count > 0
        flash[:alert] = _("%{contacts_count:referrals} couldn't be added because they were missing a first name or you put in a bad email address.").to_str.localize %
          { contacts_count: @bad_contacts_count, referrals: { one: _('1 referral'), other: _('%{contacts_count} referrals') } }

      end
    end
  end

  def find_duplicates
    @page_title = _('Find Duplicates')

    respond_to do |wants|
      wants.html {  }
      wants.js do
        # Find sets of people with the same name
        sql = "SELECT array_to_string(array_agg(people.id), ',')
               FROM people
               INNER JOIN contact_people ON people.id = contact_people.person_id
               INNER JOIN contacts ON contact_people.contact_id = contacts.id
               WHERE contacts.account_list_id = #{current_account_list.id}
               AND name not like '%nonymous%'
               AND first_name not like '%nknow%'
               GROUP BY first_name, last_name
               HAVING count(*) > 1"
        people_with_duplicate_names = Person.connection.select_values(sql)
        @contact_sets = []
        contacts_checked = []
        people_with_duplicate_names.each do |pair|
          contacts = current_account_list.contacts.people.includes(:people).where('people.id' => pair.split(','))[0..1]
          if contacts.length > 1
            already_included = false
            contacts.each { |c| already_included = true if contacts_checked.include?(c) }
            next if already_included
            contacts_checked += contacts
            unless contacts.first.not_same_as?(contacts.last)
              @contact_sets << contacts
            end
          end
        end
        @contact_sets.sort_by! { |s| s.first.name }
      end
    end
  end

  def not_duplicates
    contacts = current_account_list.contacts.where(id: params[:ids])
    contacts.each do |contact|
      not_duplicated_with = (contact.not_duplicated_with.to_s.split(',') + params[:ids].split(',') - [contact.id.to_s]).uniq.join(',')
      contact.update_attributes(not_duplicated_with: not_duplicated_with)
    end

    respond_to do |wants|
      wants.html { redirect_to :back }
      wants.js { render nothing: true }
    end
  end


  private

  def get_contact
    @contact = current_account_list.contacts.includes({people: [:primary_email_address, :primary_phone_number, :email_addresses, :phone_numbers, :family_relationships]}).find(params[:id])
  end

  def setup_filters
    current_user.contacts_filter ||= {}
    clear_filters = params.delete(:clear_filter)
    if filters_params.present?
      current_user.contacts_filter[current_account_list.id] = filters_params
      current_user.save
    elsif clear_filters == 'true'
      current_user.contacts_filter[current_account_list.id] = nil
      current_user.save
    end

    if current_user.contacts_filter.present? && current_user.contacts_filter[current_account_list.id].present?
      @filters_params = current_user.contacts_filter[current_account_list.id]
    end
  end

  def filtered_contacts
    filtered_contacts = current_account_list.contacts.order('contacts.name')

    if params[:filter] == 'people'
      filtered_contacts = filtered_contacts.people
    end

    if params[:filter] == 'companies'
      filtered_contacts = filtered_contacts.companies
    end

    if filters_params.present?
      ContactFilter.new(filters_params).filter(filtered_contacts)
    else
      filtered_contacts.active
    end
  end

end
