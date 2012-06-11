class DonationExhibit < Exhibit

  def self.applicable_to?(object)
    object.is_a?(Donation)
  end

  def to_s() amount; end

  def amount
    @context.number_to_current_currency(self[:amount], {currency: currency})
  end

end
