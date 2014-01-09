class PersonExhibit < DisplayCase::Exhibit
  include DisplayCase::ExhibitsHelper

  def self.applicable_to?(object)
    object.class.name == 'Person'
  end

  def age(now = Time.now.utc.to_date)
    return nil unless [birthday_day, birthday_month, birthday_year].all?(&:present?)
    now.year - birthday_year - ((now.month > birthday_month || (now.month == birthday_month && now.day >= birthday_day)) ? 0 : 1)
  end

  def company_position_description
    description = @context.link_to(company_position.company, company_position.company)
    description = company_position.position + ', ' + description if company_position.position.present?
    description.html_safe
  end

  #def location
    #[address.city, address.state, address.country].select(&:present?).join(', ') if address
  #end

  def contact_info
    [phone_number, email].compact.map {|e| exhibit(e, @context)}.join('<br />').html_safe
  end

  def avatar(size = :square)
    return primary_picture.image.url(size) if primary_picture && primary_picture.image.url(size)
    return "https://graph.facebook.com/#{facebook_account.remote_id}/picture?type=#{size}" if facebook_account

    if gender == 'female'
      @context.image_url('avatar_f.png')
    else
      @context.image_url('avatar.png')
    end
  end


  def twitter_handles
    twitter_accounts.collect {|t| @context.link_to("@#{t.screen_name}", "http://twitter.com/#{t.screen_name}", target: '_blank') }.join(', ').html_safe
  end

  def to_s
    name = [first_name, last_name].compact.join(' ')
    if deceased?
      name = "<del>#{name}</del>".html_safe
    end
    name
  end

end
