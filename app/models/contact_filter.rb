class ContactFilter
  attr_accessor :contacts, :filters

  def initialize(filters = nil)
    @filters = filters || {}

    # strip extra spaces from filters
    @filters.map { |k, v| @filters[k] = v.strip if v.is_a?(String) }
  end

  def filter(contacts)
    filtered_contacts = contacts

    if filters.present?
      if @filters[:ids]
        filtered_contacts = filtered_contacts.where('contacts.id' => @filters[:ids].split(','))
      end

      if @filters[:tags].present? && @filters[:tags].first != ''
        filtered_contacts = filtered_contacts.tagged_with(@filters[:tags].split(','))
      end

      if @filters[:name_like]
        # See if they've typed a first and last name
        if @filters[:name_like].split(/\s+/).length > 1
          filtered_contacts = filtered_contacts.where("concat(first_name,' ',last_name) like ? ", "%#{@filters[:name_like]}%")
        else
          filtered_contacts = filtered_contacts.where('first_name like :search OR last_name like :search',
                                                      search: "#{@filters[:name_like]}%")
        end
      end

      if @filters[:city].present? && @filters[:city].first != ''
        filtered_contacts = filtered_contacts.where('addresses.city' => @filters[:city])
                                             .includes(:addresses)
                                             .references('addresses')
      end

      if @filters[:church].present? && @filters[:church].first != ''
        filtered_contacts = filtered_contacts.where('contacts.church_name' => @filters[:church])
      end

      if @filters[:state].present? && @filters[:state].first != ''
        filtered_contacts = filtered_contacts.where('addresses.state' => @filters[:state])
                                             .includes(:addresses)
                                             .references('addresses')
      end

      if @filters[:likely].present? && @filters[:likely].first != ''
        filtered_contacts = filtered_contacts.where(likely_to_give: @filters[:likely])
      end

      if @filters[:status].present? && @filters[:status].first != ''
        if !@filters[:status].include? '*'
          if (@filters[:status].include? '') && !(@filters[:status].include?('null'))
            @filters[:status] << 'null'
          end

          if (@filters[:status].include? 'null') && !(@filters[:status].include?(''))
            @filters[:status] << ''
          end

          if @filters[:status].include? 'null'
            filtered_contacts = filtered_contacts.where('status is null OR status in (?)', @filters[:status])
          else
            filtered_contacts = filtered_contacts.where(status: @filters[:status])
          end
        end
      else
        filtered_contacts = filtered_contacts.active
      end

      if @filters[:referrer].present? && @filters[:referrer].first != ''
        if(@filters[:referrer].first == '*')
          filtered_contacts = filtered_contacts.joins(:contact_referrals_to_me).where('contact_referrals.referred_by_id is not null').uniq
        else
          filtered_contacts = filtered_contacts.joins(:contact_referrals_to_me).where('contact_referrals.referred_by_id' => @filters[:referrer]).uniq
        end
      end

      if @filters[:newsletter].present?
        case @filters[:newsletter]
        when 'none'
          filtered_contacts = filtered_contacts.where("send_newsletter is null OR send_newsletter = ''")
        when 'address'
          filtered_contacts = filtered_contacts.joins(:addresses).where(send_newsletter: %w(Physical Both))
        when 'email'
          filtered_contacts = filtered_contacts.where(send_newsletter: %w(Email Both))
                                               .where('email_addresses.email is not null')
                                               .includes(people: :email_addresses)
                                               .references('email_addresses')
        else
          filtered_contacts = filtered_contacts.where("send_newsletter is not null AND send_newsletter <> ''")
        end
        filtered_contacts = filtered_contacts.uniq unless filtered_contacts.to_sql.include?('DISTINCT')
      end

      if @filters[:name].present?
        filtered_contacts = filtered_contacts.where('lower(contacts.name) like ?', "%#{@filters[:name].downcase}%")
      end

      if @filters[:timezone].present? && @filters[:timezone].first != ''
        filtered_contacts = filtered_contacts.where('contacts.timezone' => @filters[:timezone])
      end

      case @filters[:contact_type]
      when 'person'
        filtered_contacts = filtered_contacts.people
      when 'company'
        filtered_contacts = filtered_contacts.companies
      end

      if @filters[:wildcard_search].present? && @filters[:wildcard_search] != 'null'
        filtered_contacts = filtered_contacts.where('lower(email_addresses.email) like :search OR lower(contacts.name) like :search OR lower(donor_accounts.account_number) like :search OR lower(phone_numbers.number) like :search', search: "%#{@filters[:wildcard_search].downcase}%")
        .includes(people: :email_addresses)
        .references('email_addresses')
        .includes(:donor_accounts)
        .references('donor_accounts')
        .includes(people: :phone_numbers)
        .references('phone_numbers')
      end
    end

    filtered_contacts
  end
end
