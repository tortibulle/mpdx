class ContactFilter
  attr_accessor :contacts, :filters

  def initialize(filters = nil)
    @filters = filters || {}

    # strip extra spaces from filters
    @filters.collect { |k, v| @filters[k] = v.strip if v.is_a?(String) }
  end

  def filter(contacts)
    filtered_contacts = contacts

    if filters.present?
      if @filters[:ids]
        filtered_contacts = filtered_contacts.where('contacts.id' => @filters[:ids].split(','))
      end

      if @filters[:tags].present?
        filtered_contacts = filtered_contacts.tagged_with(@filters[:tags].split(','))
      end

      if @filters[:name_like]
        # See if they've typed a first and last name
        if @filters[:name_like].split(/\s+/).length > 1
          filtered_contacts = filtered_contacts.where("concat(first_name,' ',last_name) like ? ", "%#{@filters[:name_like]}%")
        else
          filtered_contacts = filtered_contacts.where("first_name like :search OR last_name like :search",
                                                   {search: "#{@filters[:name_like]}%"})
        end
      end

      if @filters[:city].present? && @filters[:city].first != ''
        filtered_contacts = filtered_contacts.includes(:addresses).where('addresses.city' => @filters[:city])
      end

      if @filters[:state].present? && @filters[:state].first != ''
        filtered_contacts = filtered_contacts.includes(:addresses).where('addresses.state' => @filters[:state])
      end

      if @filters[:likely].present? && @filters[:likely].first != ''
        filtered_contacts = filtered_contacts.where(likely_to_give: @filters[:likely])
      end

      if @filters[:status].present? && @filters[:status].first != ''
        if(@filters[:status].first == 'null')
          filtered_contacts = filtered_contacts.where(status: "")
        else
          filtered_contacts = filtered_contacts.where(status: @filters[:status])
        end
      else
        filtered_contacts = filtered_contacts.active
      end

      if @filters[:referrer].present? && @filters[:referrer].first != ''
        if(@filters[:referrer].first == '*')
          filtered_contacts = filtered_contacts.joins(:contact_referrals_to_me).where('contact_referrals.referred_by_id is not null')
        else
          filtered_contacts = filtered_contacts.joins(:contact_referrals_to_me).where('contact_referrals.referred_by_id' => @filters[:referrer])
        end
      end

      if @filters[:newsletter].present?
        case @filters[:newsletter]
        when 'address'
          filtered_contacts = filtered_contacts.where(send_newsletter: ['Physical', 'Both'])
          filtered_contacts = filtered_contacts.joins(:addresses).where('addresses.street is not null')
        when 'email'
          filtered_contacts = filtered_contacts.where(send_newsletter: ['Email', 'Both'])
          filtered_contacts = filtered_contacts.joins(people: :email_addresses)
        else
          filtered_contacts = filtered_contacts.where('send_newsletter is not null')
        end
        filtered_contacts = filtered_contacts.uniq unless filtered_contacts.to_sql.include?('DISTINCT')
      end
    end

    filtered_contacts
  end
end

