namespace :mailchimp do
  desc 'Sync MPDX users to mailchimp list'
  task sync: :environment do
    gb = Gibbon.new(APP_CONFIG['mailchimp_key'])
    User.includes(:primary_email_address).where("sign_in_count > 0").find_each do |u|
      if u.email
        vars = { :EMAIL => u.email.email, :FNAME => u.first_name,
               :LNAME => u.last_name}
        gb.list_subscribe(id: APP_CONFIG['mailchimp_list'], email_address: vars[:EMAIL], update_existing: true,
                          double_optin: false, merge_vars: vars, send_welcome: false, replace_interests: true)
      end
    end
  end
end
