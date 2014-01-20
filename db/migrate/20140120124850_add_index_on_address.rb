class AddIndexOnAddress < ActiveRecord::Migration
  def change
    Address.connection.execute(
      'CREATE INDEX index_addresses_on_lower_street
       ON addresses
       (lower(street));'
    )
  end
end
