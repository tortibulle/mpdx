class TagsController < ApplicationController
  def create
    if params[:add_tag_name].present?
      contacts = current_account_list.contacts.where(id: params[:add_tag_contact_ids].split(','))
      contacts.each do |c|
        c.tag_list.add(params[:add_tag_name].downcase.split(/[,;]/).map(&:strip))
        c.save
      end
    end
  end

  def destroy
    if params[:remove_tag_name].present?
      contacts = current_account_list.contacts.where(id: params[:remove_tag_contact_ids].split(','))
      contacts.each do |c|
        c.tag_list.remove(params[:remove_tag_name].downcase)
        c.save
      end
    end
  end
end
