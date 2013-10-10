# Be sure to restart your server when you modify this file.

require 'action_dispatch/middleware/session/dalli_store'
Mpdx::Application.config.session_store ActionDispatch::Session::CacheStore, :namespace => 'sessions', :key => '_mpdx_session', :expire_after => 2.days

#Mpdx::Application.config.session_store :cookie_store, :key => '_mpdx_session'

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Mpdx::Application.config.session_store :active_record_store
