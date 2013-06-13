class ActivityCommentsController < ApplicationController
  before_filter :get_activity
  respond_to :js

  def create
    @comment = @activity.activity_comments.new(params[:activity_comment])
    @comment.person_id = current_user.id
    @comment.save
  end

  def destroy
    @comment = @activity.activity_comments.find(params[:id])
    @comment.destroy
  end

  protected

  def get_activity
    if params[:activity_id]
      @activity = current_account_list.activities.find(params[:activity_id])
    end
  end

end
