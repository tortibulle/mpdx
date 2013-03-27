class TaskFilter

  attr_accessor :tasks, :filters

  def initialize(filters)
    @filters = filters

    # strip extra spaces from filters
    @filters.collect { |k, v| @filters[k] = v.strip if v.is_a?(String) }
  end

  def filter(tasks)
    filtered_tasks = tasks

    if @filters[:contact_ids].present? && @filters[:contact_ids].first != ''
      filtered_tasks = filtered_tasks.where('contacts.id' => @filters[:contact_ids])
    end

    if @filters[:tags].present?
      filtered_tasks = filtered_tasks.tagged_with(@filters[:tags])
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
    end

    filtered_tasks
  end
end

