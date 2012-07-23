class Api::V1::TasksController < Api::V1::BaseController

  def index
    json = {tasks: ActiveModel::ArraySerializer.new(current_account_list.tasks.includes(:contacts, :activity_comments)).as_json}
    if params[:include_contacts]
      json[:contacts] = ActiveModel::ArraySerializer.new(Contact.where(id: current_account_list.tasks.collect(&:contact_ids).flatten)).as_json
    end
    render json: json, callback: params[:callback]
  end

end
