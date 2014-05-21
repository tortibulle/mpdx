class TaskFilter

  attr_accessor :tasks, :filters

  def initialize(filters)
    @filters = filters || {}

    # strip extra spaces from filters
    @filters.collect { |k, v| @filters[k] = v.strip if v.is_a?(String) }
  end

  def filter(tasks)
    filtered_tasks = tasks

    if @filters[:contact_ids].present? && @filters[:contact_ids].first != ''
      filtered_tasks = filtered_tasks.where('contacts.id' => @filters[:contact_ids])
    end

    if @filters[:completed].present?
      filtered_tasks = filtered_tasks.where(completed: @filters[:completed])
    end

    if @filters[:overdue].present?
      if(@filters[:overdue].to_s == 'true')
        filtered_tasks = filtered_tasks.overdue
      else
        filtered_tasks = filtered_tasks.where('start_at > ?', Time.now.beginning_of_day)
      end
    end

    if @filters[:tags].present? && @filters[:tags].first != ''
      filtered_tasks = filtered_tasks.tagged_with(@filters[:tags])
    end

    if @filters[:starred].present?
      filtered_tasks = filtered_tasks.where(starred: @filters[:starred])
    end

    if @filters[:activity_type].present? && @filters[:activity_type].first != ''
      filtered_tasks = filtered_tasks.where(activity_type: @filters[:activity_type])
    end

    case @filters[:date_range]
    when 'last_month'
      filtered_tasks = filtered_tasks.where('completed_at > ?', 1.month.ago)
    when 'last_year'
      filtered_tasks = filtered_tasks.where('completed_at > ?', 1.year.ago)
    when 'last_two_years'
      filtered_tasks = filtered_tasks.where('completed_at > ?', 2.years.ago)
    when 'last_week'
      filtered_tasks = filtered_tasks.where('completed_at > ?', 1.week.ago)
    when 'overdue'
      filtered_tasks = filtered_tasks.overdue
    when 'today'
      filtered_tasks = filtered_tasks.today
    when 'tomorrow'
      filtered_tasks = filtered_tasks.tomorrow
    when 'future'
      filtered_tasks = filtered_tasks.future
    when 'upcoming'
      filtered_tasks = filtered_tasks.upcoming
    end

    filtered_tasks
  end
end

