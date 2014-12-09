class Api::V1::ContactsController < Api::V1::BaseController
  def index
    order = params[:order] || 'contacts.name'

    if params[:filters].present?
      filtered_contacts = ContactFilter.new(params[:filters]).filter(contacts)
    else
      filtered_contacts = contacts.active
    end
    inactivated = contacts.inactive.where('updated_at > ?', Time.at(params[:since].to_i)).pluck(:id)

    filtered_contacts = add_includes_and_order(filtered_contacts, order: order)

    if params[:since]
      meta = {
        deleted: Version.where(item_type: 'Contact', event: 'destroy', related_object_type: 'AccountList', related_object_id: current_account_list.id)
                        .where('created_at > ?', Time.at(params[:since].to_i)).pluck(:item_id),
        inactivated: inactivated
      }
    else
      meta = {}
    end

    meta.merge!(total: filtered_contacts.total_entries, from: correct_from(filtered_contacts),
                to: correct_to(filtered_contacts), page: page,
                total_pages: total_pages(filtered_contacts)) if filtered_contacts.respond_to?(:total_entries)

    render json: filtered_contacts,
           serializer: ContactArraySerializer,
           scope: { include: includes, since: params[:since], user: current_user },
           meta: meta,
           callback: params[:callback],
           root: :contacts
  end

  def show
    render json: contacts.find(params[:id]),
           scope: { include: includes, since: params[:since] },
           callback: params[:callback]
  end

  def update
    contact = contacts.find(params[:id])
    if contact.update_attributes(contact_params)
      render json: contact, callback: params[:callback]
    else
      render json: { errors: contact.errors.full_messages }, callback: params[:callback], status: :bad_request
    end
  end

  def create
    contact = contacts.new(contact_params)
    if contact.save
      render json: contact, callback: params[:callback], status: :created
    else
      render json: { errors: contact.errors.full_messages }, callback: params[:callback], status: :bad_request
    end
  end

  def destroy
    contact = contacts.find(params[:id])
    contact.destroy
    render json: contact, callback: params[:callback]
  end

  def count
    if params[:filters].present?
      filtered_contacts = ContactFilter.new(params[:filters]).filter(contacts)
    else
      filtered_contacts = contacts.active
    end

    render json: { total: filtered_contacts.count }, callback: params[:callback]
  end

  def tags
    render json: { tags: current_account_list.contact_tags }, callback: params[:callback]
  end

  protected

  def contacts
    current_account_list.contacts
  end

  def available_includes
    if !params[:include]
      includes = [{ people: [:email_addresses, :phone_numbers, :facebook_account] }, :addresses, { primary_person: :facebook_account }]
    else
      includes = []

      includes << { people: [:email_addresses, :phone_numbers, :facebook_account] } if params[:include].include?('Person.')
      includes << :addresses if params[:include].include?('Address.')
      includes << { primary_person: :facebook_account } if params[:include].include?('avatar')
    end
    includes
  end

  def contact_params
    @contact_params ||= params.require(:contact).permit(Contact::PERMITTED_ATTRIBUTES)
  end
end
