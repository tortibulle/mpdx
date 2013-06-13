class PreferencesController < ApplicationController
  def index
    @page_title = _('Preferences')

    @preference_set = PreferenceSet.new(user: current_user, account_list: current_account_list)
  end

  def update
    @preference_set = PreferenceSet.new(params[:preference_set].merge!(user: current_user, account_list: current_account_list))
    if @preference_set.save
      redirect_to preferences_path, notice: _('Preferences saved')
    else
      flash.now[:alert] = @preference_set.errors.full_messages.join('<br />').html_safe
      render "index"
    end
  end
end
