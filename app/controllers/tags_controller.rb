class TagsController < ApplicationController
  def create
    if params[:acts_as_taggable_on_tag][:name].present?
      contacts = current_account_list.contacts.find_all_by_id(params[:contact_ids].split(','))
      contacts.each do |c|
        c.tag_list << params[:acts_as_taggable_on_tag][:name]
        c.save
      end
    end
    redirect_to :back
  end

  def destroy
  end
end
