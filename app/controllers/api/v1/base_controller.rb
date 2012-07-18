class Api::V1::BaseController < ApplicationController
  skip_before_filter :ensure_login, :ensure_setup_finished

  protected

    def current_user
      unless @current_user
        if token = oauth_access_token
          @current_user = User.from_access_token(token)
        else
          @current_user = super
        end
      end
      @current_user
    end

    def oauth_access_token
      params[:access_token] || oauth_access_token_from_header
    end


    # grabs access_token from header if one is present
    def oauth_access_token_from_header
      auth_header = request.env["HTTP_AUTHORIZATION"]||""
      match       = auth_header.match(/^token\s(.*)/) || auth_header.match(/^Bearer\s(.*)/)
      return match[1] if match.present?
      false
    end
end
