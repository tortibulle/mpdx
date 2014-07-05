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
          format.html { render action: 'new' }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @person.update_attributes(person_params)
        format.html { redirect_to @person }
      else
        format.html { render action: 'edit' }
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
    params.require(:person).permit(Person::PERMITTED_ATTRIBUTES)
  end
end
