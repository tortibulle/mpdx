class TagsController < ApplicationController
  def create
    if params[:add_tag_name].present?
      contacts = current_account_list.contacts.find_all_by_id(params[:add_tag_contact_ids].split(','))
      contacts.each do |c|
        c.tag_list << params[:add_tag_name].downcase
        c.save
      end
    end
  end

  def destroy
    if params[:remove_tag_name].present?
      contacts = current_account_list.contacts.find_all_by_id(params[:remove_tag_contact_ids].split(','))
      contacts.each do |c|
        c.tag_list = c.tag_list.map(&:downcase) - [params[:remove_tag_name].downcase]
        c.save
      end
    end
  end
end
