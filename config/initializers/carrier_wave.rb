require Rails.root.join('config','initializers','load_config').to_s
CarrierWave.configure do |config|
  config.fog_credentials = {
    :provider               => 'AWS',       # required
    :aws_access_key_id      => APP_CONFIG['s3_key'],       # required
    :aws_secret_access_key  => APP_CONFIG['s3_secret']       # required
  }
  config.fog_directory  = APP_CONFIG['s3_bucket']                     # required
  config.fog_public     = false                                   # optional, defaults to true
  config.fog_attributes = { 'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
end
