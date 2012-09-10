class SiebelTemp < DataServer

  def check_credentials!
    raise OrgAccountMissingCredentialsError, I18n.t('data_server.missing_username_password') unless @org_account.token.present?
    raise OrgAccountInvalidCredentialsError, I18n.t('data_server.invalid_username_password', org: @org) unless @org_account.valid_credentials?
  end

  def requires_username_and_password?
    false
  end
  protected
  def get_params(raw_params, options={})
    params_string = raw_params.dup
    params_string.sub!('$PROFILE$', options[:profile]) if options[:profile]
    params_string.sub!('$DATEFROM$', options[:datefrom]) if options[:datefrom]
    params_string.sub!('$DATETO$', options[:dateto]) if options[:dateto]
    params_string.sub!('$PERSONIDS$', options[:personid]) if options[:personid]
    params = Hash[params_string.split('&').collect {|p| p.split('=')}]
    params['access_token'] = @org_account.token
    params
  end

  def get_response(url, params)
    RestClient::Request.execute(:method => :post, :url => url, :payload => params, :timeout => -1) { |response, request, result, &block|
      Rails.logger.ap request
      Rails.logger.ap response
      # check for error response
      raise DataServerError, "No data for #{params}" if response.blank?
      first_line = response.split("\n").first.to_s.upcase
      if response.code.to_i == 500 || first_line.include?('ERROR') || first_line.include?('BAD_PASSWORD') || first_line.include?('HTML')
        raise DataServerError, response.to_str
      end
      response.to_str
    }
  end
end
