class ContactExhibit < Exhibit
  include ExhibitsHelper

  def self.applicable_to?(object)
    object.is_a?(Contact)
  end

  def referrer_links
    referrals_to_me.collect {|r| @context.link_to(exhibit(r, @context), r)}.join(', ').html_safe
  end


  def location
    [address.city, address.state, address.country].select(&:present?).join(', ') if address
  end

  def contact_info
    people.collect {|p| 
      p = exhibit(p, @context)
      email = p.primary_email_address || p.email_addresses.first
      [@context.link_to(p, @context.contact_person_path(self, p)), [p.phone_number, email].compact.map {|e| exhibit(e, @context)}.join(', ')].select(&:present?).join(': ')
    }.join('<br />').html_safe
  end

  def avatar
    'avatar.png'
  end

  def pledge_as_currency
    @context.number_to_currency(pledge_amount, precision: 0)
  end

  def likely_to_give
    return nil unless to_model.likely_to_give
    Contact.giving_likelihoods[to_model.likely_to_give - 1]
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
