class ImportsController < ApplicationController
  def create
    if import_params
      import = current_account_list.imports.new(import_params)
      import.user_id = current_user.id

      if import.save
        flash[:notice] = _('MPDX is currently importing your contacts from %{source}. You will receive an email when the import is complete.').localize % { source: params[:import][:source] }
      else
        flash[:alert] = import.errors.full_messages.join('<br>').html_safe
      end
    end

    redirect_to :back
  end

  private

  def import_params
    group_tags = params.require(:import).fetch(:group_tags, nil).try(:permit!)
    params.require(:import)
      .permit(:source, :source_account_id, :file, :tags, :override, :import_by_group, groups: [])
      .merge(group_tags: group_tags)
  end
end
