class DonationExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.class.name == 'Donation'
  end

  def to_s() amount; end

  def tendered_amount
    @context.number_to_current_currency(self[:tendered_amount], {currency: currency, precision: self[:tendered_amount] == self[:tendered_amount].to_i ? 0 : 2})
  end

end
