namespace :mailchimp do
  desc 'Sync MPDX users to mailchimp list'
  task sync: :environment do
    gb = Gibbon.new(APP_CONFIG['mailchimp_key'])

    CURRENT_USER_RANGE = 180.days.ago

    # Subscribe anyone who has logged in in the past [CURRENT_USER_RANGE] days
    User.includes(:primary_email_address).where(
      "sign_in_count > 0 and current_sign_in_at > ? and subscribed_to_updates IS NULL", CURRENT_USER_RANGE
    ).find_each do |u|
      if u.email
        vars = { :EMAIL => u.email.email, :FNAME => u.first_name,
               :LNAME => u.last_name}
        begin
          gb.list_subscribe(id: APP_CONFIG['mailchimp_list'], email_address: vars[:EMAIL], update_existing: true,
                            double_optin: false, merge_vars: vars, send_welcome: false, replace_interests: true)
          u.update_column(:subscribed_to_updates, true)

        rescue Gibbon::MailChimpError => e
          case
            when e.message.include?('code 502')
              # Invalid email address
              u.update_column(:subscribed_to_updates, false)
            else
              raise
          end
        end
      end
    end

    # Unsubscribe anyone who has NOT logged in in the past [CURRENT_USER_RANGE] days
    User.includes(:primary_email_address).where(
      "sign_in_count > 0 and current_sign_in_at < ? and subscribed_to_updates = ?", CURRENT_USER_RANGE, true
    ).find_each do |u|
      if u.email
        begin
          gb.list_unsubscribe(id: APP_CONFIG['mailchimp_list'], email_address: u.email.email,
                              send_goodbye: false, delete_member: true)
          u.update_column(:subscribed_to_updates, nil)
          puts "Unsubscribed #{u.first_name} #{u.last_name} - #{u.email.email}"
        rescue Gibbon::MailChimpError => e
          case
            when e.message.include?('code 232')
              # Email address is already unsubscribed
              u.update_column(:subscribed_to_updates, false)
            else
              raise
          end
        end
      end
    end
  end
end
