class AccountListExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.is_a?(AccountList)
  end

  def to_s
    designation_accounts.collect(&:name).join(', ')
  end

  def balances
    return '' if designation_accounts.length == 0
    if designation_accounts.length > 1
      balance = designation_profile.balance ? designation_profile.balance : designation_accounts.collect(&:balance).reduce(&:+)
    else
      balance = designation_accounts.first.balance
    end
    "<div class=\"account_balances lots\">#{_('Balance: %{balance}') %{balance: @context.number_to_current_currency(balance)}}</div>".html_safe # <a href=\"#show\" class=\"plain\">Details</a></div>
  end


end

