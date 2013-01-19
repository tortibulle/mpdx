OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
OmniAuth.config.full_host = 'http://' + ActionMailer::Base.default_url_options[:host]
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, APP_CONFIG['twitter_key'], APP_CONFIG['twitter_secret']
  provider :facebook, APP_CONFIG['facebook_key'], APP_CONFIG['facebook_secret'], :scope => 'user_about_me,user_activities,user_birthday,friends_birthday,user_education_history,friends_education_history,user_hometown,friends_hometown,user_interests,friends_interests,user_likes,friends_likes,user_location,friends_location,user_relationships,friends_relationships,user_relationship_details,friends_relationship_details,user_religion_politics,friends_religion_politics,user_work_history,friends_work_history,friends_website,read_mailbox,read_stream,publish_stream,manage_pages,friends_about_me,friends_activities,'
  provider :linkedin, APP_CONFIG['linkedin_key'], APP_CONFIG['linkedin_secret']
  provider :google_oauth2, APP_CONFIG['google_key'], APP_CONFIG['google_secret'], :name => 'google', :scope => 'userinfo.email,userinfo.profile,https://mail.google.com/mail/feed/atom/,https://www.google.com/m8/feeds/'
  provider :cas, name: 'relay', host: 'signin.relaysso.org/cas'
  provider :cas, name: 'key', host: 'thekey.me/cas'
  provider :cas, name: 'admin', host: 'signin.relaysso.org/cas'
end
