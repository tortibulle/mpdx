# Be sure to restart your server when you modify this file.

require 'action_dispatch/middleware/session/dalli_store'
Mpdx::Application.config.session_store ActionDispatch::Session::CacheStore, :namespace => 'sessions', :key => '_mpdx_session', :expire_after => 2.days

#Mpdx::Application.config.session_store :cookie_store, :key => '_mpdx_session'
