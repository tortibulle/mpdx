class SocialStreamsController < ApplicationController
  def index
    if params[:contact_id]
      @contact = current_account_list.contacts.where(id: params[:contact_id]).first
      @items = []

      begin
        @graph = Koala::Facebook::API.new(current_user.facebook_account.try(:token))
        @contact.people.each do |person|
          person.facebook_accounts.each do |account|
            @items += @graph.get_connections(account.remote_id, "posts").collect { |json| SocialItem.new(json) }
          end
        end
        @items.sort!
      rescue Koala::Facebook::AuthenticationError
        @bad_facebook_token = true
      end
    end
  end
end
