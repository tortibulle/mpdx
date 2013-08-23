class ContactExhibit < DisplayCase::Exhibit
  include DisplayCase::ExhibitsHelper

  def self.applicable_to?(object)
    object.class.name == 'Contact'
  end

  def referrer_links
    referrals_to_me.collect {|r| @context.link_to(exhibit(r, @context), r, remote: true)}.join(', ').html_safe
  end


  def location
    [address.city, address.state, address.country].select(&:present?).join(', ') if address
  end

  def contact_info
    people.collect {|p|
      person_exhibit = exhibit(p, @context)
      email = p.primary_email_address || p.email_addresses.first
      [@context.link_to(person_exhibit, @context.contact_person_path(to_model, p)), [person_exhibit.phone_number, person_exhibit.email].compact.map {|e| exhibit(e, @context)}.join('<br />')].select(&:present?).join(':<br />')
    }.join('<br />').html_safe
  end

  def pledge_frequency
    Contact.pledge_frequencies[to_model.pledge_frequency]
  end

  def avatar(size = :square)
    if picture = primary_or_first_person.primary_picture
      picture.image.url(size)
    else
      fb = primary_or_first_person.facebook_account
      return "https://graph.facebook.com/#{fb.remote_id}/picture?type=#{size}" if fb
      'https://mpdx.org/assets/' + if primary_or_first_person.gender == 'female'
        'avatar_f.png'
      else
        'avatar.png'
      end
    end
  end

  def pledge_as_currency
    if pledge_amount.present?
      pledge = if pledge_amount % 1 > 0
        @context.number_to_currency(pledge_amount, precision: 2)
      else
        @context.number_to_currency(pledge_amount, precision: 0)
      end
      pledge += " #{Contact.pledge_frequencies[to_model.pledge_frequency || 1.0]}"
      pledge
    end
  end

  def notes_saved_at
    return '' unless to_model.notes_saved_at
    to_model.notes_saved_at.to_datetime.localize(@context.locale).to_medium_s
    #@context.l(to_model.notes_saved_at.to_datetime, :medium)
  end

  def tag_links
    tags.collect do |tag|
      @context.link_to(tag, @context.params.except(:action, :controller, :id).merge(action: :index, filters: {tags: tag.name}), class: "tag")
    end.join(' ').html_safe
  end

  def donor_ids
    donor_accounts.collect(&:account_number).join(', ')
  end

  def to_s
    name
  end

  def send_newsletter_error
    missing_address = (mailing_address == Address.new)
    missing_email_address = people.joins(:email_addresses).blank?

    case
    when send_newsletter == 'Both' && missing_address && missing_email_address
      _('No mailing address or email addess on file')
    when (send_newsletter == 'Physical' || send_newsletter == 'Both') && missing_address
      _('No mailing address on file')
    when (send_newsletter == 'Email' || send_newsletter == 'Both') && missing_email_address
      _('No email addess on file')
    end
  end
end
