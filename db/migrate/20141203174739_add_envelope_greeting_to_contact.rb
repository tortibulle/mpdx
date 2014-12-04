class AddEnvelopeGreetingToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :envelope_greeting, :string
  end
end
