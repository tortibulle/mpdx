class SetupController < ApplicationController
  include Wicked::Wizard

  skip_before_action :ensure_setup_finished
  before_action :ensure_org_account, only: :show

  steps :org_accounts, :social_accounts, :finish

  def show
    case step
    when :org_accounts
      skip_step if current_user.organization_accounts.present?
    when :social_accounts
    when :finish
      current_user.setup_finished!
      redirect_to '/'
      return
    end
    render_wizard
  end

  protected

  def ensure_org_account
    return if step == :org_accounts
    unless current_user.organization_accounts.present?
      redirect_to wizard_path(:org_accounts), alert: _('You need to be connected to an organization to use MPDX.')
      return false
    end
  end
end
