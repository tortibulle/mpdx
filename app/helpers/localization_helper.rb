module LocalizationHelper
  def number_to_current_currency(value, options={})
    options[:precision] ||= 0
    options[:currency] ||= current_currency
    options[:locale] ||= locale
    begin
      value.to_f.localize(options[:locale]).to_currency.to_s(options)
    rescue Errno::ENOENT
      value.to_f.localize(:es).to_currency.to_s(options)
    end
  end

  def current_currency(account_list=nil, user=nil)
    unless @current_currency
      account_list ||= current_account_list
      user ||= current_user
      @current_currency = if designation_profile = account_list.designation_profile(user)
        designation_profile.organization.default_currency_code
      end
      @current_currency ||= 'USD'
    end
    @current_currency
  end
end
