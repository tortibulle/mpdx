class SocialStreamsController < ApplicationController
  def index
    if params[:contact_id]
      @contact = current_account_list.contacts.where(id: params[:contact_id]).first
      @items = []

      if current_user.facebook_account.try(:token) &&
         !current_user.facebook_account.token_missing_or_expired?
        @graph = Koala::Facebook::API.new(current_user.facebook_account.token)
        @contact.people.each do |person|
          person.facebook_accounts.each do |account|
            @items += @graph.get_connections(account.remote_id, "posts").collect { |json| SocialItem.new(json) }
          end
        end
        @items.sort!
      end
    end
  end
end
