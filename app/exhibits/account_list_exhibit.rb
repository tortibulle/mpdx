class AccountListExhibit < DisplayCase::Exhibit
  def self.applicable_to?(object)
    object.class.name == 'AccountList'
  end

  def to_s
    designation_accounts.map(&:name).join(', ')
  end

  def balances(user)
    return '' if designation_accounts.length == 0
    if designation_accounts.length > 1
      balance = designation_profile(user).try(:balance) ? designation_profile(user).balance.to_i : designation_accounts.map { |da| da.balance.to_i }.reduce(&:+)
    else
      balance = designation_accounts.first.balance.to_i
    end
    "<div class=\"account_balances tip\" title=\"#{_('May take a few days to update')}\">#{_('Balance: %{balance}').localize % { balance: @context.number_to_current_currency(balance) }}</div>".html_safe
    # <a href=\"#show\" class=\"plain\">Details</a></div>
  end
end
