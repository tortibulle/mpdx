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

  #def edit
    #@organization_account = Person::OrganizationAccount.find(params[:id])
  #end

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

  #def update
    #@organization_account = Person::OrganizationAccount.find(params[:id])

    #respond_to do |format|
      #if @organization_account.update_attributes(params[:organization_account])
        #format.html { redirect_to @organization_account, notice: 'Organization account was successfully updated.' }
      #else
        #format.html { render action: "edit" }
      #end
    #end
  #end

  #def destroy
    #@organization_account = Person::OrganizationAccount.find(params[:id])
    #@organization_account.destroy

    #respond_to do |format|
      #format.html { redirect_to person_organization_accounts_url }
    #end
  #end
end
