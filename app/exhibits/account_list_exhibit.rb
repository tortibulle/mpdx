class AccountListExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.class.name == 'AccountList'
  end

  def to_s
    designation_accounts.collect(&:name).join(', ')
  end

  def balances
    return '' if designation_accounts.length == 0
    if designation_accounts.length > 1
      balance = designation_profile.try(:balance) ? designation_profile.balance.to_i : designation_accounts.collect {|da| da.balance.to_i }.reduce(&:+)
    else
      balance = designation_accounts.first.balance.to_i
    end
    "<div class=\"account_balances lots\">#{_('Balance: %{balance}') %{balance: @context.number_to_current_currency(balance)}}</div>".html_safe # <a href=\"#show\" class=\"plain\">Details</a></div>
  end


end

