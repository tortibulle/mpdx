require 'csv'

# Load the db/nicknames.csv file which was taken from
# https://code.google.com/p/nickname-and-diminutive-names-lookup

namespace :nicknames do
  task load: :environment do
    nicknames = []
    nicknames_csv = File.new('db/nicknames.csv').read
    CSV.new(nicknames_csv).each do |line|
      primary_name = ''
      line.each_with_index do |name, index|
        if index == 0
          primary_name = name
        else
          nicknames << [primary_name, name]
        end
      end
    end

    nicknames.each do |names|
      name, nickname = names
      begin
        Nickname.create(name: name, nickname: nickname, source: 'csv', suggest_duplicates: true)
      rescue ActiveRecord::RecordNotUnique
        # Do nothing if the name-nickname pair already exists
      end
    end
  end
end
