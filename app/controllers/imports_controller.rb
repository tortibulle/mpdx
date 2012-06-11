class ImportsController < ApplicationController

  def create
    Import
    if params[:import]
      import = current_account_list.imports.new(params[:import])
      import.user_id = current_user.id

      if import.save
        unless import.source == 'file'
          current_user.import_contacts_from(import)
        end
      else
        flash[:alert] = _('Please choose a file that ends with .csv')
      end
    end

    redirect_to :back
  end
end
