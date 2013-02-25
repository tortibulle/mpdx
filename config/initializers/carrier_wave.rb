require Rails.root.join('config','initializers','load_config').to_s

if Rails.env.test? or Rails.env.cucumber?
  CarrierWave.configure do |config|
    config.storage = :file
    #config.enable_processing = false
  end
else
  CarrierWave.configure do |config|
    config.fog_credentials = {
      :provider               => 'AWS',       # required
      :aws_access_key_id      => APP_CONFIG['s3_key'],       # required
      :aws_secret_access_key  => APP_CONFIG['s3_secret']       # required
    }
    config.fog_directory  = APP_CONFIG['s3_bucket']                     # required
    config.fog_public     = false                                   # optional, defaults to true
    config.fog_attributes = { 'x-amz-storage-class' => 'REDUCED_REDUNDANCY' }
    config.fog_authenticated_url_expiration = 1.month
    config.storage :fog
  end
end
