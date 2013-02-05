class AccountsController < ApplicationController
  skip_before_filter :ensure_login, only: :create
  skip_before_filter :ensure_setup_finished, only: :create

  def index
  end

  def new
    if params[:redirect]
      session[:user_return_to] = params[:redirect]
    end
    redirect_to "/auth/#{params[:provider]}"
  end

  def create
    User.transaction do
      provider = "Person::#{params[:provider].titleize}Account".constantize

      # If we don't have a current user, login with this method
      unless user_signed_in?
        session[:signed_in_with] = params[:provider]
        sign_in(User.from_omniauth(provider, request.env['omniauth.auth']))
        session[:user_return_to] ||= '/'

        # queue up data imports
        current_user.queue_imports
      end

      # Connect this account to the user
      @account = provider.find_or_create_from_auth(request.env['omniauth.auth'], current_user)

      redirect_to redirect_path
      session[:user_return_to] = nil
    end
  end

  def destroy
    # if they're trying to delete a key or relay account, make sure they have at least
    # one way to log in
    if %w[key relay].include?(params[:provider])
      unless current_user.key_accounts.length + 
             current_user.relay_accounts.length > 1
        redirect_to redirect_path, alert: _("If we let you delete that account you won't be able to log in anymore")
        return
      end
    end
    base = current_user.send("#{params[:provider]}_accounts".to_sym)
    base.find(params[:id]).destroy
    redirect_to redirect_path
  end

  def failure
    flash[:alert] = t('accounts.unable_to_connect')
    redirect_to redirect_path
  end

  private
    def redirect_path
      case
      when current_user.setup_mode?
        if current_user.organization_accounts.present?
          setup_path(:social_accounts)
        else
          setup_path(:org_accounts)
        end
      when session[:user_return_to]
        session[:user_return_to]
      else
        accounts_path
      end
    end
end
