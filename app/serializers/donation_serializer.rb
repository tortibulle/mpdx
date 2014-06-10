class DonationSerializer < ActiveModel::Serializer
  include LocalizationHelper

  embed :ids, include: true
  attributes :id, :amount, :donation_date

  def amount
    account_list = scope[:account_list]
    user = scope[:user]
    current_currency(account_list, user)

    number_to_current_currency(object.amount, locale: scope[:locale])
  end

end
