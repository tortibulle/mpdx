require Rails.root.join('config','initializers','load_config').to_s
# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Mpdx::Application.config.secret_token = '90aec68792c54b1986fefe40ca8102318be8b54ea484cbd2b8fbe3ee1a741388a61a06c37d1421be92b5bdb7fc0c4a84613c6f3ae4b16592308c7477fb368f00'
Mpdx::Application.config.secret_key_base = APP_CONFIG['linkedin_secret']
