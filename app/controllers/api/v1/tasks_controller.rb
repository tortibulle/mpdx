class Api::V1::TasksController < Api::V1::BaseController

  def index
    render json: current_account_list.tasks.includes(:contacts, :activity_comments)
  end

end
