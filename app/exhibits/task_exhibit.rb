class TaskExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.class.name == 'Task'
  end

  def to_s
    subject
  end

  def css_class
    case
    when start_at < Time.now then 'high'
    when Time.now - start_at < 1.day then 'mid'
    else ''
    end
  end

  def contact_links
    contacts.collect { |c| @context.link_to(c.to_s, c) }.join(', ').html_safe
  end

  def tag_links
    tags.collect do |tag|
      @context.link_to(tag, @context.params.except(:action, :controller, :id).merge(action: :index, tags: tag.name), class: "tag")
    end.join(' ').html_safe
  end

end
