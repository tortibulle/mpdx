class SocialStreamsController < ApplicationController
  def index
    if params[:contact_id]
      @contact = current_account_list.contacts.where(id: params[:contact_id]).first
      @items = []
      @names = {}

      begin
        @graph = Koala::Facebook::API.new(current_user.facebook_account.try(:token))
        @contact.people.each do |person|
          person.facebook_accounts.each do |account|
            results = @graph.fql_multiquery({query1: "SELECT post_id, actor_id, target_id, action_links, attachment, message, description, type, created_time FROM stream WHERE source_id = #{account.remote_id} AND actor_id = #{account.remote_id} LIMIT 50",
                                             query2: "SELECT uid, name FROM user WHERE uid IN (SELECT actor_id FROM #query1) OR uid IN (SELECT target_id FROM #query1)"})
            @names.merge!(Hash[results['query2'].collect { |json| [json['uid'], json['name']] }])
            @items += results['query1'].collect { |json| SocialItem.new(json, @names) }
          end
        end
        @items.sort!
      rescue Koala::Facebook::AuthenticationError, Koala::Facebook::ClientError
        @bad_facebook_token = true
      end
    end
  end
end
