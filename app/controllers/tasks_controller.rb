class TasksController < ApplicationController
  respond_to :html, :js

  def index
    base_scope = current_account_list.tasks.uncompleted

    if params[:tags].present?
      base_scope = base_scope.tagged_with(params[:tags])
    end

    if params[:activity_type].present? && params[:activity_type].first != ''
      base_scope = base_scope.where(activity_type: params[:activity_type])
    end

    @overdue = base_scope.overdue
    @tomorrow = base_scope.tomorrow
    @upcoming = base_scope.upcoming
  end

  def starred
    @tasks = current_account_list.tasks.uncompleted.starred
  end

  def completed
    @tasks = current_account_list.tasks.completed.order('start_at desc')
  end

  def history
    
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

  def destroy
    @task = current_account_list.tasks.find(params[:id])
    @task.destroy

    respond_to do |format|
      format.html { redirect_to :back }
    end
  end
end
