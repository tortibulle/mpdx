class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :ensure_login, :ensure_setup_finished
  around_filter :do_with_current_user, :set_user_time_zone


  private

  def ensure_login
    unless user_signed_in?
      if $request_test
        sign_in(:user, $user)
      else
        session[:user_return_to] = request.fullpath unless request.path == '/'
        case 
        when request.host =~ /us/
          redirect_to '/auth/relay'
        when request.host =~ /mpdxs|key/
          redirect_to '/auth/key'
        else
          redirect_to '/login'
        end
        return false
      end
    end
  end

  def ensure_setup_finished
    if user_signed_in? && (current_user.setup_mode? || !current_account_list) && request.path != '/logout'
      redirect_to setup_path(:org_accounts)
      return false
    end
  end

  def set_user_time_zone
    old_time_zone = Time.zone
    if user_signed_in? && current_user.preferences[:time_zone]
      Time.zone = current_user.preferences[:time_zone]
    else
      if cookies[:timezone]
        Time.zone = ActiveSupport::TimeZone[-cookies[:timezone].to_i.minutes]
        current_user.update_attribute(:time_zone, Time.zone.name) if user_signed_in?
      end
    end
    yield
  ensure
    Time.zone = old_time_zone
  end

  def after_sign_out_path_for(resource_or_scope = :user)
    case session[:signed_in_with]
    when 'relay'
      "https://signin.relaysso.org/cas/logout?service=#{login_url}"
    when 'key'
      "https://thekey.me/cas/logout?service=#{login_url}"
    else
      login_url
    end
  end

  def locale
    user_signed_in? && current_user.preferences[:locale].present? ?  current_user.preferences[:locale] : :en
  end
  helper_method :locale

  def current_account_list
    account_list = current_user.account_lists.find_by_id(session[:current_account_list_id]) if session[:current_account_list_id].present?
    account_list ||= current_user.account_lists.first
    account_list ||= current_user.organization_accounts.first.create_default_profile if current_user.organization_accounts.first
    session[:current_account_list_id] = account_list.id if account_list
    account_list
  end
  helper_method :current_account_list

  def do_with_current_user
    Thread.current[:user] = current_user
    begin
      yield
    ensure
      Thread.current[:user] = nil
    end
  end

end
