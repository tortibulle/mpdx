class ResearchController < ApplicationController
  before_action :ensure_rollout

  def index
  end

  def search
    @contact = current_account_list.contacts.find(params[:id])
    account_numbers = @contact.donor_accounts.pluck(:account_number)
    @donor_data = @contact.donor_accounts.present? ? SiebelDonations::Donor.find(ids: account_numbers.join(',')) : []
    [@contact.primary_person, @contact.spouse].compact.each do |person|
      first_name = person.legal_first_name.present? ? person.legal_first_name : person.first_name

      search = {
        last_name: person.last_name,
        first_name: first_name
      }
      if @contact.mailing_address.state.present?
        search[:state] = @contact.mailing_address.state
        search[:city] = @contact.mailing_address.city
      end

      @donor_data = SiebelDonations::Donor.find(search) if @donor_data == []
    end

    @other_contacts = Contact.joins(:donor_accounts)
      .where('donor_accounts.account_number' => account_numbers)
      .where.not('contacts.id' => @contact.id)
  end

  private

  def ensure_rollout
    return if $rollout.active?(:research, current_account_list)
    fail ActionController::RoutingError.new('Not Found'), 'Research access not granted.'
  end
end
