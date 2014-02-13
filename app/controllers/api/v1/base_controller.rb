class Api::V1::BaseController < ApplicationController
  skip_before_filter :redirect_to_mobile
  skip_before_filter :verify_authenticity_token
  skip_before_filter :redirect_to_mobile
  before_filter :cors_preflight_check
  after_filter :cors_set_access_control_headers

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  # If this is a preflight OPTIONS request, then short-circuit the
  # request, return only the necessary headers and return an empty
  # text/plain.

  def cors_preflight_check
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version, API-VERSION, Authorization'
    headers['Access-Control-Max-Age'] = '1728000'
    head(:ok) if request.request_method == "OPTIONS"
  end

  protected
    # For all responses in this controller, return the CORS access control headers.
    def cors_set_access_control_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Allow-Headers'] = 'API-VERSION, Authorization'
      headers['Access-Control-Max-Age'] = "1728000"
    end

    def ensure_login
      return if request.request_method == "OPTIONS"
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

    def ensure_setup_finished
      return if request.request_method == "OPTIONS"
      unless current_account_list
        render json: {errors: _('You need to go to http://mpdx.org and set up your account before using the mobile app.')},
               callback: params[:callback],
               status: :unauthorized
        return false
      end
    end

    def current_user
      @current_user ||= User.from_access_token(oauth_access_token)
    end

    def current_account_list
      account_list = current_user.account_lists.find(params[:account_list_id]) if params[:account_list_id].present?
      account_list ||= default_account_list
      account_list
    end

    def oauth_access_token
      @oauth_access_token ||= (params[:access_token] || oauth_access_token_from_header)
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

    def add_includes_and_order(resource, options = {})
      # eager loading is a waste of time if the 'since' parameter is passed
      unless params[:since]
        resource = resource.includes(available_includes) if available_includes.present?
      end
      resource = resource.where("#{resource.table.name}.updated_at > ?", Time.at(params[:since].to_i)) if params[:since].to_i > 0
      resource = resource.limit(params[:limit]) if params[:limit]
      resource = resource.offset(params[:offset]) if params[:offset]
      resource = resource.order(options[:order]) if options[:order]
      resource
    end

    # let the api use add additional relationships to this call
    def includes
      @includes ||= params[:include].to_s.split(',')
    end

    # Each controller should override this method
    def available_includes
      []
    end
end
