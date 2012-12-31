module ApplicationHelper
  include DisplayCase::ExhibitsHelper

  def auth_link(provider)
    if current_user.send("#{provider}_accounts".to_sym).length == 0
      prompt = _('Add an Account')
    else
      prompt = _('Add another Account') unless "Person::#{provider.titleize}Account".constantize.one_per_user?
    end
    link_to(prompt, "/auth/#{provider}", :class => "btn") if prompt
  end

  def link_to_remove_fields(f, hidden)
    f.hidden_field(:_destroy) + link_to(_('Remove'), 'javascript:void(0)', class: 'ico ico_trash', style: hidden ? 'display:none' : '', data: {behavior: 'remove_field'})
  end

  def link_to_add_fields(name, f, association, options = {})
    partial = options[:partial] || "#{association.to_s.singularize}_fields"
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(partial, :builder => builder, no_remove: false, object: f.object)
    end
    link_to_function(name, raw("addFields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"), class: "add_field")
  end

  def tip(tip, options = {})
    tag('span', class: 'qtip', title: tip, style: options[:style])
  end

  def spinner(options = {})
    id = options[:extra] ? "spinner_#{options[:extra]}" : 'spinner'
    style = options[:visible] ? '' : 'display:none'
    image_tag('spinner.gif', id: id, style: style, class: 'spinner')
  end

  def number_to_current_currency(value, options={})
    options[:precision] ||= 0
    options[:currency] ||= current_account_list.designation_profile.organization.default_currency_code if current_account_list.designation_profile
    begin
      value.to_f.localize(locale).to_currency.to_s(options)
    rescue Errno::ENOENT
      value.to_f.localize(:es).to_currency.to_s(options)
    end
    #number_to_currency(value, options)
  end

  def l(date, options = {})
    options[:format] ||= :short
    if [:full, :long, :medium, :short].include?(options[:format])
      date.localize(locale).send("to_#{options[:format]}_s".to_sym)
    else
      super
    end
  end

  def all_contacts
    @contacts ||= current_account_list.contacts.order('contacts.name')
    @all_contacts ||= @contacts.select(['contacts.id', 'contacts.name'])
  end

  def contacts_for_filter
    current_account_list.contacts.order('contacts.name').select(['contacts.id', 'contacts.name'])
  end


end
