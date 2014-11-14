class DonationSerializer < ActiveModel::Serializer
  include LocalizationHelper

  embed :ids, include: true
  attributes :id, :amount, :donation_date, :contact_id, :appeal_id

  def amount
    account_list = scope[:account_list]
    user = scope[:user]
    current_currency(account_list, user)

    number_to_current_currency(object.amount, locale: scope[:locale])
  end

  def contact_id
    object.donor_account.contacts.where(account_list_id: scope[:account_list].id).first.id
  end
end
