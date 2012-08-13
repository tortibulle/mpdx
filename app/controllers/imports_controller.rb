class ImportsController < ApplicationController

  def create
    if params[:import]
      import = current_account_list.imports.new(params[:import])
      import.user_id = current_user.id

      if import.save
        current_user.import_contacts_from(import)
      else
        flash[:alert] = import.errors.full_messages.join('<br>').html_safe
      end
    end

    redirect_to :back
  end
end
