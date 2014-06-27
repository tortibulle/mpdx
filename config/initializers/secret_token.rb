require Rails.root.join('config','initializers','load_config').to_s
# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Mpdx::Application.config.secret_key_base = APP_CONFIG['linkedin_secret']
