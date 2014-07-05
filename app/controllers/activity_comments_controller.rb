class ActivityCommentsController < ApplicationController
  before_action :get_activity
  respond_to :js

  def create
    @comment = @activity.activity_comments.new(activity_comment_params)
    @comment.person_id = current_user.id
    @comment.save
  end

  def destroy
    @comment = @activity.activity_comments.find(params[:id])
    @comment.destroy
  end

  protected

  def get_activity
    return unless params[:activity_id]
    @activity = current_account_list.activities.find(params[:activity_id])
  end

  def activity_comment_params
    params.require(:activity_comment).permit(:body)
  end
end
