class PreferencesController < ApplicationController
  def update
    current_user.update_attributes(params[:user])
    redirect_to :back, notice: _('Preferences saved')
  end
end
