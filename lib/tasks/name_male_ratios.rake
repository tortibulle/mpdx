require 'csv'

# Load the db/name_male_ratios_usa_1960_to_2013.csv file which was compiled from data at:
# http://www.ssa.gov/oact/babynames/limits.html

namespace :name_male_ratios do
  task load: :environment do
    CSV.new(File.new('db/name_male_ratios_usa_1960_to_2013.csv').read).each do |line|
      begin
        NameMaleRatio.create(name: line[0], male_ratio: line[1].to_f)
      rescue ActiveRecord::RecordNotUnique
        # Do nothing if the name male ratio already exists
      end
    end
  end
end
