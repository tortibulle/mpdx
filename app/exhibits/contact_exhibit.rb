class ContactExhibit < DisplayCase::Exhibit
  include DisplayCase::ExhibitsHelper

  def self.applicable_to?(object)
    object.class.name == 'Contact'
  end

  def referrer_links
    referrals_to_me.collect {|r| @context.link_to(exhibit(r, @context), r)}.join(', ').html_safe
  end


  def location
    [address.city, address.state, address.country].select(&:present?).join(', ') if address
  end

  def contact_info
    people.collect {|p| 
      person_exhibit = exhibit(p, @context)
      email = p.primary_email_address || p.email_addresses.first
      [@context.link_to(p, @context.contact_person_path(to_model, p)), [person_exhibit.phone_number, person_exhibit.email].compact.map {|e| exhibit(e, @context)}.join(', ')].select(&:present?).join(': ')
    }.join('<br />').html_safe
  end

  def avatar(size = :square)
    fb = people.collect(&:facebook_account).flatten.first
    fb ? "https://graph.facebook.com/#{fb.remote_id}/picture?type=#{size}" : 'https://mpdx.org/assets/avatar.png'
  end

  def pledge_as_currency
    pledge = @context.number_to_currency(pledge_amount, precision: 0)
    pledge += " #{Contact.pledge_frequencies[pledge_frequency]}" if pledge_frequency.present?
  end

  def notes_saved_at
    return '' unless to_model.notes_saved_at
    to_model.notes_saved_at.to_datetime.localize(@context.locale).to_medium_s
    #@context.l(to_model.notes_saved_at.to_datetime, :medium)
  end

  def tag_links
    tags.collect do |tag|
      @context.link_to(tag, @context.params.except(:action, :controller, :id).merge(action: :index, tags: tag.name), class: "tag")
    end.join(' ').html_safe
  end

  def to_s
    name
  end

end
