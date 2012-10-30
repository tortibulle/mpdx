class Api::V1::BaseController < ApplicationController
  skip_before_filter :redirect_to_mobile
  skip_before_filter :ensure_setup_finished

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  protected

    def ensure_login
      unless oauth_access_token
        render json: {errors: ['Missing access token']}, status: :unauthorized, callback: params[:callback]
        return false
      end
      begin
        unless current_user
          render json: {errors: ['Please go to http://mpdx.org and log in using Relay before trying to use the mobile app.']},
                 status: :unauthorized,
                 callback: params[:callback]
          return false
        end
      rescue RestClient::Unauthorized
        render json: {errors: ['Invalid access token']}, status: :unauthorized, callback: params[:callback]
        return false
      end
    end

    def current_user
      @current_user ||= User.from_access_token(oauth_access_token)
    end

    def current_account_list
      account_list = current_user.account_lists.find(params[:account_list_id]) if params[:account_list_id].present?
      account_list ||= super
      account_list
    end

    def oauth_access_token
      oauth_access_token ||= (params[:access_token] || oauth_access_token_from_header)
    end


    # grabs access_token from header if one is present
    def oauth_access_token_from_header
      auth_header = request.env["HTTP_AUTHORIZATION"]||""
      match       = auth_header.match(/^token\s(.*)/) || auth_header.match(/^Bearer\s(.*)/)
      return match[1] if match.present?
      false
    end

    def render_404
      render nothing: true, status: 404
    end
end
