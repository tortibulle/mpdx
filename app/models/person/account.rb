module Person::Account
  def self.extended(base)
    base.send :belongs_to, :person
    base.send :scope, :authenticated, conditions: {authenticated: true}
  end

  def self.queue() :import; end

  def find_or_create_from_auth(auth_hash, person)
    @attributes.merge!(authenticated: true)
    @account = @rel.find_by_remote_id_and_authenticated(@remote_id, true)
    if @account
      @account.update_attributes(@attributes, without_protection: true)
      person.update_attributes(@attributes.slice(:first_name, :last_name, :email))
    else
      # if creating this authentication record is a duplicate, we have a duplicate person to merge
      if other_account = find_by_remote_id_and_authenticated(@remote_id, true)
        other_account.update_attributes({person_id: person.id}, without_protection: true)
        @account = other_account
      else
        @account = @rel.create!(@attributes, without_protection: true)
      end
    end

    # start a data import in the background
    @account.queue_import_data if @account.respond_to?(:queue_import_data)

    @account
  end

  def create_user_from_auth(auth_hash)
    @attributes ||= {}
    User.create!(@attributes, without_protection: true)
  end

  def find_authenticated_user(auth_hash)
    User.find_by_id(authenticated.where(remote_id: auth_hash.uid).pluck(:person_id).first)
  end

  def one_per_user?() true; end

end
