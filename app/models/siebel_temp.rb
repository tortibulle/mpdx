class SiebelTemp < DataServer

  def check_credentials!
    raise OrgAccountMissingCredentialsError, _('Your username and password are missing for this account.') unless @org_account.token.present?
    raise OrgAccountInvalidCredentialsError, _('Your username and password for %{org} are invalid.') % { org: @org } unless @org_account.valid_credentials?
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
    params['ssoGuid'] = @org_account.user.relay_accounts.first.remote_id
    params
  end

  def get_response(url, params)
    RestClient::Request.execute(:method => :post, :url => url, :payload => params, :timeout => -1) { |response, request, result, &block|
      Rails.logger.ap request
      Rails.logger.ap response
      # check for error response
      raise DataServerError, "No data for #{params}" if response.blank?
      first_line = response.split("\n").first.to_s.upcase
      case
      when first_line.include?('BAD_PASSWORD')
        raise OrgAccountInvalidCredentialsError, _("Your username and password for %{org} are invalid.") % { org: @org }
      when response.code.to_i == 500 || first_line.include?('ERROR') || first_line.include?('HTML')
        raise DataServerError, response.to_str
      end
      response = response.to_str.unpack("C*").pack("U*")
      # Strip annoying extra unicode at the beginning of the file
      response = response[3..-1] if response.first.localize.code_points.first == 239
      response
    }
  end
end
