class Api::V1::TasksController < Api::V1::BaseController

  def index
    render json: tasks, callback: params[:callback]
  end

  def show
    render json: tasks.find(params[:id]), callback: params[:callback]
  end

  def update
    task = tasks.find(params[:id])
    if task.update_attributes(params[:task])
      render json: task, callback: params[:callback]
    else
      render json: {errors: task.errors.full_messages}, callback: params[:callback], status: :bad_request
    end
  end

  def create
    task = tasks.new(params[:task])
    if task.save
      render json: task, callback: params[:callback], status: :created
    else
      render json: {errors: task.errors.full_messages}, callback: params[:callback], status: :bad_request
    end
  end

  def destroy
    task = tasks.find(params[:id])
    task.destroy
    render json: task, callback: params[:callback]
  end

  protected

  def tasks
    current_account_list.tasks.includes(:contacts, :activity_comments)
  end

end
