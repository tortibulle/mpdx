class DonationExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.class.name == 'Donation'
  end

  def to_s() amount; end

  def tendered_amount
    @context.number_to_current_currency(self[:tendered_amount], {currency: currency})
  end

end
