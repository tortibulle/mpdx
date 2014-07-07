module Person::Account
  extend ActiveSupport::Concern

  included do
    belongs_to :person
    scope :authenticated, -> { where(authenticated: true) }
  end

  module ClassMethods
    def find_or_create_from_auth(_auth_hash, person)
      @attributes.merge!(authenticated: true)
      @account = @rel.find_by_remote_id_and_authenticated(@remote_id, true)
      if @account
        @account.update_attributes(@attributes)
      else
        # if creating this authentication record is a duplicate, we have a duplicate person to merge
        if other_account = find_by_remote_id_and_authenticated(@remote_id, true)
          other_account.update_attributes(person_id: person.id)
          @account = other_account
        else
          @account = @rel.create!(@attributes)
        end
      end

      person.first_name = @attributes[:first_name] if person.first_name.blank?
      person.last_name = @attributes[:last_name] if person.last_name.blank?
      person.email = @attributes[:email] if person.email.blank?

      # start a data import in the background
      @account.queue_import_data if @account.respond_to?(:queue_import_data)

      @account
    end

    def create_user_from_auth(_auth_hash)
      @attributes ||= {}
      User.create!(@attributes)
    end

    def find_authenticated_user(auth_hash)
      User.find_by_id(authenticated.where(remote_id: auth_hash.uid).pluck(:person_id).first)
    end

    def one_per_user?() true; end

    def queue() :import; end
  end

  class NoSessionError < StandardError
  end
end
