class TaskExhibit < DisplayCase::Exhibit
  def self.applicable_to?(object)
    object.class.name == 'Task'
  end

  def to_s
    subject
  end

  def css_class
    case
    when to_model.start_at < Time.now then 'high'
    when Time.now - to_model.start_at < 1.day then 'mid'
    else ''
    end
  end

  def contact_links
    if contacts.length > 3
      (contacts[0..1].collect { |c| @context.link_to(c.to_s, c) }.join('; ') +
       @context.link_to(_('... Show More'), '#', class: 'task_show_more') +
       '<span class="task_all_contacts" style="display:none">' + contacts.collect { |c| @context.link_to(c.to_s, c) }.join('; ') + '</span>').html_safe
    else
      contacts.collect { |c| @context.link_to(c.to_s, c) }.join('; ').html_safe
    end
  end

  def tag_links
    tags.collect do |tag|
      @context.link_to(tag, @context.params.except(:action, :controller, :id).merge(action: :index, tags: tag.name), class: 'tag')
    end.join(' ').html_safe
  end

  def completed_at
    to_model.completed_at ? @context.l(to_model.completed_at.to_datetime) : ''
  end

  def start_at
    to_model.start_at ? @context.l(to_model.start_at.to_datetime) : ''
  end
end
