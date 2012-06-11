class TaskExhibit < Exhibit

  def self.applicable_to?(object)
    object.is_a?(Task)
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


end
