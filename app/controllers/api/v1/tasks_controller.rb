class Api::V1::TasksController < Api::V1::BaseController

  def index
    render json: tasks,
           scope: {since: params[:since]},
           meta:  params[:since] ?
                    {deleted: Version.where(item_type: 'Activity', event: 'destroy', related_object_type: 'AccountList', related_object_id: current_account_list.id).where("created_at > ?", Time.at(params[:since].to_i)).pluck(:item_id)} :
                    {},
           callback: params[:callback]
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
    add_includes_and_order(current_account_list.tasks.includes(:contacts, :activity_comments, :people), order: params[:order])
  end

end
