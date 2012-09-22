class Person::OrganizationAccountsController < ApplicationController
  skip_before_filter :ensure_setup_finished, only: [:new, :create]

  respond_to :js, :html

  def new
    @organization = Organization.find(params[:id])
    @organization_account = current_user.organization_accounts.new(organization: @organization)

    respond_to do |format|
      format.js
    end
  end

  def create
    @organization_account = current_user.organization_accounts.new(params[:person_organization_account])
    @organization = @organization_account.organization

    respond_to do |format|
      if @organization && @organization_account.save
        format.js
      else
        format.js { render action: "new" }
      end
    end
  end

end
