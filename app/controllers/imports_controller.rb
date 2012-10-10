class ImportsController < ApplicationController

  def create
    if params[:import]
      import = current_account_list.imports.new(params[:import])
      import.user_id = current_user.id

      if import.save
        flash[:notice] = _('MPDX is currently importing your contacts from %{source}. You will receive an email when the import is complete.') % { source: params[:import][:source] }
      else
        flash[:alert] = import.errors.full_messages.join('<br>').html_safe
      end
    end

    redirect_to :back
  end
end
