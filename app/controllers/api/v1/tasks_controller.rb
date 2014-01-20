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
    if task.update_attributes(task_params)
      render json: task, callback: params[:callback]
    else
      render json: {errors: task.errors.full_messages}, callback: params[:callback], status: :bad_request
    end
  end

  def create
    task = tasks.new(task_params)
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

  # yields {"total": ##,"uncompleted": ##,"overdue": ##}
  def count
    render json: {total: tasks.count, uncompleted: tasks.uncompleted.count, overdue: tasks.overdue.count}, callback: params[:callback]
  end

  protected

  def tasks
    filtered_tasks = TaskFilter.new(params[:filters]).filter(current_account_list.tasks)

    add_includes_and_order(filtered_tasks.includes(:contacts, :activity_comments, :people), order: params[:order])
  end

  def task_params
    params.require(:task).permit(Task::PERMITTED_ATTRIBUTES)
  end
end
