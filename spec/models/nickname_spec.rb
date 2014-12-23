require 'spec_helper'

describe Nickname do
  describe '#increment_times_merged' do
    it 'calls find_and_increment_counter' do
      expect(Nickname).to receive(:find_and_increment_counter).with('John', 'Johnny', :num_merges)
      Nickname.increment_times_merged('John', 'Johnny')
    end
  end

  describe '#increment_not_duplicates' do
    it 'calls find_and_increment_counter' do
      expect(Nickname).to receive(:find_and_increment_counter).with('John', 'Johnny', :num_not_duplicates)
      Nickname.increment_not_duplicates('John', 'Johnny')
    end
  end

  describe '#find_and_increment_counter' do
    it 'finds an existing nickname and increments its counter' do
      nickname = Nickname.create(name: 'john', nickname: 'johnny')
      expect {
        Nickname.find_and_increment_counter('John', 'Johnny', :num_merges)
        nickname.reload
      }.to change(nickname, :num_merges).from(0).to(1)
    end

    it 'creates a new nickname and increments its counter' do
      expect {
        Nickname.find_and_increment_counter('John', 'Johnny', :num_merges)
      }.to change(Nickname, :count).from(0).to(1)
      expect(Nickname.first.num_merges).to eq(1)
    end
  end
end
