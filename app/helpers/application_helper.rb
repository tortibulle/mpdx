module ApplicationHelper
  include DisplayCase::ExhibitsHelper
  include LocalizationHelper

  def auth_link(provider)
    if current_user.send("#{provider}_accounts".to_sym).length == 0
      prompt = _('Add an Account')
    else
      prompt = _('Add another Account') unless "Person::#{provider.camelcase}Account".constantize.one_per_user?
    end
    link_to(prompt, "/auth/#{provider}", class: 'btn') if prompt
  end

  def link_to_remove_fields(f, hidden = false)
    f.hidden_field(:_destroy) + link_to(_('Remove'), 'javascript:void(0)', class: 'ico ico_trash', style: hidden ? 'display:none' : '', data: { behavior: 'remove_field' })
  end

  def link_to_add_fields(name, f, association, options = {})
    partial = options[:partial] || "#{association.to_s.singularize}_fields"
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, child_index: "new_#{association}") do |builder|
      render(partial, builder: builder, object: f.object)
    end
    link_to_function(name, raw("addFields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"), class: 'add_field')
  end

  def link_to_clear_contact_filters(f)
    link_to(f, contacts_path(clear_filter: true))
  end

  def tip(tip, options = {})
    tag('span', class: 'qtip', title: tip, style: options[:style])
  end

  def spinner(options = {})
    id = options[:extra] ? "spinner_#{options[:extra]}" : 'spinner'
    style = options[:visible] ? '' : 'display:none'
    image_tag('spinner.gif', id: id, style: style, class: 'spinner')
  end

  def l(date, options = {})
    options[:format] ||= :date_time
    date = date.to_datetime unless date.class == Date || date.class == DateTime
    if date.class == Date
      date = date.to_datetime.localize(FastGettext.locale).to_date
    else
      date = Time.zone.utc_to_local(date)
      date = date.to_datetime.localize(FastGettext.locale)
    end

    if [:full, :long, :medium, :short].include?(options[:format])
      date.send("to_#{options[:format]}_s".to_sym)
    else
      case options[:format]
      when :month_abbrv
        date.to_s(format: 'MMM')
      when :date_time
        date.to_short_s
      else
        date.to_s(format: options[:format])
      end
    end
  end

  def contacts_for_filter
    current_account_list.contacts.order('contacts.name').select(['contacts.id', 'contacts.name'])
  end

  # Renders a message containing number of displayed vs. total entries.
  #
  #   <%= page_entries_info @posts %>
  #   #-> Displaying posts 6 - 12 of 26 in total
  #
  # The default output contains HTML. Use ":html => false" for plain text.
  def page_entries_info(collection, options = {})
    if options.fetch(:html, true)
      b, eb = '<b>', '</b>'
      sp = '&nbsp;'
      # html_key = '_html'
    else
      b = eb = ''
      # html_key = b
      sp = ' '
    end

    case collection.total_entries
    when 0, 1 then ''
    else
      _("Displaying #{b}%{from}#{sp}-#{sp}%{to}#{eb} of #{b}%{count}#{eb}").localize % {
        count: collection.total_entries,
        from: collection.offset + 1, to: collection.offset + collection.length
      }
    end.html_safe
  end

  def calendar_date_select_tag(name, value = nil, options = {})
    options.merge!('data-calendar' => true)
    options.merge!('id' => '')
    options.merge!('style' => 'width:100px;')
    options.merge!('readonly' => '')
    value = case
            when value.is_a?(Time) || value.is_a?(DateTime)
              l(value.to_date)
            when value.is_a?(Date)
              l(value)
            else
              value
            end
    text_field_tag(name, value, options)
  end
end
