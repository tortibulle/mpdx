class ContactMerge
  def initialize(winner, loser)
    @winner = winner
    @other = loser
  end

  def merge
    Contact.transaction do
      # Update related records
      @other.messages.update_all(contact_id: @winner.id)

      @other.contact_people.each do |r|
        next if @winner.contact_people.where(person_id: r.person_id).first
        r.update_attributes(contact_id: @winner.id)
      end

      @other.contact_donor_accounts.each do |other_contact_donor_account|
        next if @winner.donor_accounts.map(&:account_number).include?(other_contact_donor_account.donor_account.account_number)
        other_contact_donor_account.update_column(:contact_id, @winner.id)
      end

      @other.activity_contacts.each do |other_activity_contact|
        next if @winner.activities.include?(other_activity_contact.activity)
        other_activity_contact.update_column(:contact_id, @winner.id)
      end
      @winner.update_uncompleted_tasks_count

      @other.addresses.each do |other_address|
        next if @winner.addresses.find { |address| address.equal_to? other_address }
        other_address.update_column(:addressable_id, @winner.id)
      end

      @other.notifications.update_all(contact_id: @winner.id)

      @winner.merge_addresses

      ContactReferral.where(referred_to_id: @other.id).each do |contact_referral|
        contact_referral.update_column(:referred_to_id, @winner.id) unless @winner.contact_referrals_to_me.find_by_referred_by_id(contact_referral.referred_by_id)
      end

      ContactReferral.where(referred_by_id: @other.id).update_all(referred_by_id: @winner.id)

      # Copy fields over updating any field that's blank on the winner
      Contact::MERGE_COPY_ATTRIBUTES.each do |field|
        next unless @winner.send(field).blank? && @other.send(field).present?
        @winner.send("#{field}=".to_sym, @other.send(field))
      end

      # If one of these is marked as a finanical partner, we want that status
      if @winner.status != 'Partner - Financial' && @other.status == 'Partner - Financial'
        @winner.status = 'Partner - Financial'
      end

      # Make sure first and last donation dates are correct
      if @winner.first_donation_date && @winner.first_donation_date > @other.first_donation_date
        @winner.first_donation_date = @other.first_donation_date
      end
      if @winner.last_donation_date && @winner.last_donation_date < @other.last_donation_date
        @winner.last_donation_date = @other.last_donation_date
      end

      @winner.notes = [@winner.notes, @other.notes].compact.join("\n").strip if @other.notes.present?

      @winner.tag_list += @other.tag_list

      @winner.save(validate: false)
    end

    # Delete the losing record
    begin
      @other.reload
      @other.destroy
    rescue ActiveRecord::RecordNotFound; end

    @winner.reload
    @winner.merge_people
    @winner.merge_donor_accounts

    # Update donation total after donor account ids are all assigned correctly
    @winner.update_all_donation_totals
  end
end
