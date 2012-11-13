class MailChimpAccountsController < ApplicationController
  before_filter :get_mail_chimp_account

  def index
    
    @mail_chimp_account.validate_key if current_account_list.mail_chimp_account

    unless @mail_chimp_account.active?
      redirect_to new_mail_chimp_account_path and return
    end

    unless @mail_chimp_account.primary_list
      redirect_to edit_mail_chimp_account_path(@mail_chimp_account)
      return
    end
  end

  def create
    create_or_update
  end

  def update
    create_or_update
  end

  def new
  end

  def edit
    render :new unless @mail_chimp_account.active_and_valid?
  end

  def destroy
    current_account_list.mail_chimp_account.destroy
    redirect_to integrations_settings_path
  end

  def sync
    flash[:notice] = _("MPDX is now uploading your newsletter recipients to MailChimp.") # We'll send you an email to let you know when we're done.
    @mail_chimp_account.queue_export_to_primary_list
    redirect_to :back
  end


  private

  def create_or_update
    @mail_chimp_account.attributes = params[:mail_chimp_account]

    changed_primary = true if @mail_chimp_account.changed.include?('primary_list_id')

    if @mail_chimp_account.save && @mail_chimp_account.active?
      if @mail_chimp_account.primary_list
        if changed_primary
          flash[:notice] = _("MPDX is now uploading your newsletter recipients to MailChimp.")
        end
        redirect_to mail_chimp_accounts_path
      else
        redirect_to edit_mail_chimp_account_path(@mail_chimp_account)
      end
    else
      render :new
    end
  end


  def get_mail_chimp_account
    @mail_chimp_account = current_account_list.mail_chimp_account || 
                          current_account_list.build_mail_chimp_account

  end
end
