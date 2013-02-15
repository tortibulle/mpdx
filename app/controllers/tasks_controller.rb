class TasksController < ApplicationController
  before_filter :setup_filters, only: :index

  respond_to :html, :js

  def index
    @tasks = current_account_list.tasks.uncompleted.includes(:contacts, :activity_comments, :tags)

    @tasks = TaskFilter.new(filters_params).filter(@tasks) if filters_params.present?

    @overdue = @tasks.overdue
    @tomorrow = @tasks.tomorrow
    @upcoming = @tasks.upcoming
  end

  def starred
    @tasks = current_account_list.tasks.uncompleted.starred
  end

  def completed
    @tasks = current_account_list.tasks.completed
  end

  def history
    @tasks = current_account_list.tasks.completed
                                       .includes(:contacts, :activity_comments, :tags)
                                       .page(page).per_page(per_page)

    @tasks = TaskFilter.new(filters_params).filter(@tasks) if filters_params.present?

    case params[:date_range]
    when 'last_month'
      @tasks = @tasks.where('completed_at > ?', 1.month.ago)
    when 'last_year'
      @tasks = @tasks.where('completed_at > ?', 1.year.ago)
    when 'last_two_years'
      @tasks = @tasks.where('completed_at > ?', 2.years.ago)
    when 'all'
    else
      @tasks = @tasks.where('completed_at > ?', 1.week.ago)
    end
  end

  def show
    @task = current_account_list.tasks.find(params[:id])
  end

  def new
    @task = current_account_list.tasks.new
    @old_task = current_account_list.tasks.find_by_id(params[:from]) if params[:from]
    if @old_task
      @task.attributes = @old_task.attributes.select { |k, v| [:starred, :location, :subject].include?(k.to_sym) }
      @task.tag_list = @old_task.tag_list
      @old_task.activity_contacts.each do |ac|
        @task.activity_contacts.build(contact_id: ac.contact_id)
      end
    end
    if params[:contact_id]
      @task.activity_contacts.build(contact_id: params[:contact_id])
      session[:contact_redirect_to] = contact_path(params[:contact_id], anchor: 'tasks-tab')
    end
    if params[:completed]
      @task.completed = true
      session[:contact_redirect_to] = contact_path(params[:contact_id], anchor: 'history-tab') if params[:contact_id]
    end
  end

  def edit
    @task = current_account_list.tasks.find(params[:id])
  end

  def create
    @task = current_account_list.tasks.new(params[:task])

    if params[:add_task_contact_ids].present?
      # First validate the task fields
      if @task.valid?
        # Create a copy of the task for each contact selected
        contacts = current_account_list.contacts.find_all_by_id(params[:add_task_contact_ids].split(','))
        contacts.each do |c|
          @task = current_account_list.tasks.create(params[:task])
          ActivityContact.create(activity_id: @task.id, contact_id: c.id)
        end
      else
        render action: "new"
      end
    else
      respond_to do |format|
        if @task.save
          format.html {
            redirect_to (session[:contact_redirect_to] || tasks_path)
            session[:contact_redirect_to] = nil
          }
        else
          format.html { render action: "new" }
        end
      end
    end
  end

  def update
    @task = current_account_list.tasks.find(params[:id])

    respond_to do |format|
      if @task.update_attributes(params[:task])
        format.html { redirect_to tasks_path }
        format.js   { render nothing: true }
      else
        format.html { render action: 'edit' }
        format.js { render action: 'edit' }
      end
    end
  end

  def bulk_update
    tasks = current_account_list.tasks.where(id: params[:bulk_task_update_ids].split(','))
    attributes_to_update = params[:task].select { |_, v| v.present? }

    tasks.update_all(attributes_to_update) if attributes_to_update.present?

    respond_to do |format|
      format.html { redirect_to :back }
      format.js { render text: "document.location = '/tasks'" }
    end
  end

  def bulk_destroy
    current_account_list.tasks.where(id: params[:ids]).destroy_all
    respond_to do |format|
      format.js { render nothing: true }
    end
  end

  def destroy
    @task = current_account_list.tasks.find(params[:id])
    @task.destroy

    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  private

  def setup_filters
    current_user.tasks_filter ||= {}
    if filters_params.present?
      current_user.tasks_filter[current_account_list.id] = filters_params
    elsif params[:clear_filter] == 'true'
      current_user.tasks_filter[current_account_list.id] = nil
    end

    if current_user.tasks_filter.present? && current_user.tasks_filter[current_account_list.id].present?
      @filters_params = current_user.tasks_filter[current_account_list.id]
    end
  end
end
