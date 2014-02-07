class Person::OrganizationAccountsController < ApplicationController
  skip_before_filter :ensure_setup_finished, only: [:new, :create]

  respond_to :js, :html

  def new
    @organization = Organization.find(params[:id])
    if @organization.requires_username_and_password?
      @organization_account = current_user.organization_accounts.new(organization: @organization)

      respond_to do |format|
        format.js
      end
    else
      @organization_account = current_user.organization_accounts.create!(organization_id: @organization.id)

      respond_to do |format|
        format.js { render action: 'create' }
      end
    end

  end

  def create
    @organization_account = current_user.organization_accounts.new(person_organization_account_params)
    @organization = @organization_account.organization

    respond_to do |format|
      if @organization && @organization_account.save
        format.js
      else
        format.js { render action: "new" }
      end
    end
  end

  private
  def person_organization_account_params
    params.require(:person_organization_account).permit(:username, :password, :organization_id)
  end

end
