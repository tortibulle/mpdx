class Admin::SessionsController < ApplicationController
  def create
    if user = AdminUser.find_by_guid(auth_hash.extra.attributes.first.ssoGuid)
      sign_in(:admin_user, user)
      user.update_attribute(:email, auth_hash.uid)
      redirect_to session[:user_return_to] || '/admin'
    else
      redirect_to no_access_admin_sessions_path
    end
  end

  def failure
    redirect_to '/auth/admin'
  end

  def no_access
  end
end
