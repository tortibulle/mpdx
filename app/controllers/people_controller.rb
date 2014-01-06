class PeopleController < ApplicationController
  respond_to :html, :js
  before_filter :get_contact
  before_filter :get_person, only: [:show, :edit, :update, :social_search]

  def show
    @person = current_account_list.people.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @person = Person.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def edit
  end

  def create
    @contact = current_account_list.contacts.find(params[:contact_id])
    Person.transaction do
      @person = @contact.people.new(person_params)

      respond_to do |format|
        if @person.save
          format.html { redirect_to @contact }
        else
          format.html { render action: "new" }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @person.update_attributes(person_params)
        format.html { redirect_to @person }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @person = current_account_list.people.find(params[:id])
    @person.destroy

    respond_to do |format|
      format.html { redirect_to people_path }
    end
  end

  def merge
    ids_to_merge = params[:merge_people_ids].split(',')
    if ids_to_merge.length > 1 && ids_to_merge.include?(params[:merge_winner]) # just to be sure
      people_to_merge = @contact.people.where(id: ids_to_merge - [params[:merge_winner]])
      merge_winner = @contact.people.find(params[:merge_winner])
      people_to_merge.each do |p|
        merge_winner.merge(p)
      end
    end
  end

  private

  def get_person
    @person = current_account_list.people.find(params[:id])
  end

  def get_contact
    @contact = current_account_list.contacts.find(params[:contact_id]) if params[:contact_id]
  end

  def person_params
    params.require(:person).permit(:first_name, :legal_first_name, :last_name, :birthday_month, :birthday_year, :birthday_day, 
                                   :anniversary_month, :anniversary_year, :anniversary_day, :title, :suffix, :gender, :marital_status, 
                                   :middle_name, :profession, :deceased,
                                   {
                                     email_address: :email,
                                     phone_number: :number,
                                     email_addresses_attributes: [:email, :primary, :_destroy, :id],
                                     phone_numbers_attributes: [:number, :location, :primary, :_destroy, :id],
                                     linkedin_accounts_attributes: [:url, :_destroy, :id],
                                     facebook_accounts_attributes: [:url, :_destroy, :id],
                                     twitter_accounts_attributes: [:screen_name, :_destroy, :id],
                                     pictures_attributes: [:image_cache, :primary, :_destroy, :id],
                                     family_relationships_attributes: [:related_person_id, :relationship, :_destroy, :id]
                                   }
    )
  end
end
