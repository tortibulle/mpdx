class Nickname < ActiveRecord::Base
  def self.increment_times_merged(name, nickname)
    find_and_increment_counter(name, nickname, :num_merges)
  end

  def self.increment_not_duplicates(name, nickname)
    find_and_increment_counter(name, nickname, :num_not_duplicates)
  end

  def self.find_and_increment_counter(name, nickname, counter)
    name = name.downcase
    nickname = nickname.downcase

    return if name == nickname || name =~ /[\s\-\.]/  || nickname =~ /[\s\-\.]/ || name.length == 1 || nickname.length == 1

    nickname = find_or_create_by(name: name, nickname: nickname)
    increment_counter(counter, nickname.id)
  end
end
