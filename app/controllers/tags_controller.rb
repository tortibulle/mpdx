class TagsController < ApplicationController
  def create
    if params[:add_tag_name].present?
      contacts = current_account_list.contacts.find_all_by_id(params[:add_tag_contact_ids].split(','))
      contacts.each do |c|
        c.tag_list << params[:add_tag_name]
        c.save
      end
    end
    redirect_to :back
  end

  def destroy
    if params[:remove_tag_name].present?
      contacts = current_account_list.contacts.find_all_by_id(params[:remove_tag_contact_ids].split(','))
      contacts.each do |c|
        c.tag_list.delete(params[:remove_tag_name])
        c.save
      end
    end
    redirect_to :back
  end
end
