class HelpRequestsController < ApplicationController
  def new
    @help_request = HelpRequest.new(name: current_user.to_s,
                                    email: current_user.email)
  end

  def create
    @help_request = HelpRequest.new(help_request_params)
    if @help_request.valid?
      @help_request.browser = request.user_agent
      @help_request.user_id = current_user.id
      @help_request.account_list_id = current_account_list.id
      @help_request.session = session
      @help_request.user_preferences = current_user.preferences
      @help_request.account_list_settings = current_account_list.settings.to_s
      @help_request.save!
      render action: :thanks
    else
      render action: :new
    end
  end

  private

  def help_request_params
    params.require(:help_request).permit(:name, :browser, :problem, :email, :file, :request_type)
  end
end
