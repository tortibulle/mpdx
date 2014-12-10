class ContactExhibit < DisplayCase::Exhibit
  include DisplayCase::ExhibitsHelper
  include ApplicationHelper

  TABS = {
    'details' => _('Details'),
    'tasks' => _('Tasks'),
    'history' => _('History'),
    'referrals' => _('Referrals'),
    'notes' => _('Notes'),
    'social' => _('Social')
  }

  def self.applicable_to?(object)
    object.class.name == 'Contact'
  end

  def referrer_links
    referrals_to_me.map { |r| @context.link_to(exhibit(r, @context), r) }.join(', ').html_safe
  end

  def location
    [address.city, address.state, address.country].select(&:present?).join(', ') if address
  end

  def website
    if to_model.website.present?
      url = to_model.website.include?('http') ? to_model.website : 'http://' + to_model.website
      @context.link_to(@context.truncate(url, length: 30), url, target: '_blank')
    else
      ''
    end
  end

  def contact_info
    people.order('contact_people.primary::int desc').references(:contact_people).map {|p|
      person_exhibit = exhibit(p, @context)
      phone_and_email_exhibits = [person_exhibit.phone_number, person_exhibit.email].compact.map { |e| exhibit(e, @context) }.join('<br />')
      [@context.link_to(person_exhibit, @context.contact_person_path(to_model, p)), phone_and_email_exhibits].select(&:present?).join(':<br />')
    }.join('<br />').html_safe
  end

  def pledge_frequency
    Contact.pledge_frequencies[to_model.pledge_frequency]
  end

  def avatar(size = :square)
    if (picture = primary_or_first_person.primary_picture) && picture.image.url(size)
      picture.image.url(size)
    else
      fb = primary_or_first_person.facebook_account
      if fb
        return "https://graph.facebook.com/#{fb.remote_id}/picture?height=120&width=120" if size == :large_square
        return "https://graph.facebook.com/#{fb.remote_id}/picture?type=#{size}"
      end

      if primary_or_first_person.gender == 'female'
        url = ActionController::Base.helpers.image_url('avatar_f.png')
      else
        url = ActionController::Base.helpers.image_url('avatar.png')
      end

      if url.start_with?('/')
        root_url = (@context) ? @context.root_url : 'https://mpdx.org'
        url = URI.join(root_url, url).to_s
      end
      return url
    end
  end

  def pledge_as_currency
    return unless pledge_amount.present?
    if pledge_amount % 1 > 0
      pledge = @context.number_to_currency(pledge_amount, precision: 2)
    else
      pledge = @context.number_to_currency(pledge_amount, precision: 0)
    end
    pledge += " #{Contact.pledge_frequencies[to_model.pledge_frequency || 1.0]}"
    pledge
  end

  def notes_saved_at
    return '' unless to_model.notes_saved_at
    l(to_model.notes_saved_at.to_datetime, format: :medium)
  end

  def tag_links
    tags.map do |tag|
      @context.link_to(tag, @context.params.except(:action, :controller, :id).merge(action: :index, filters: { tags: tag.name }), class: 'tag')
    end.join(' ').html_safe
  end

  def donor_ids
    donor_accounts.map(&:account_number).join(', ')
  end

  def to_s
    name
  end

  def send_newsletter_error
    missing_address = !mailing_address.id
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
