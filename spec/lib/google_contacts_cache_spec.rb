require 'google_contacts_cache'

describe GoogleContactsCache do
  let(:john1) { double(id: 'john1', given_name: 'John', family_name: 'Doe') }
  let(:john2) { double(id: 'john2', given_name: 'John', family_name: 'Doe') }
  let(:jane1) { double(id: 'jane1', given_name: 'Jane', family_name: 'Doe') }
  let(:jane2) { double(id: 'jane2', given_name: 'Jane Doe', family_name: '') }
  let(:account) { double }
  let(:cache) { GoogleContactsCache.new(account) }

  describe 'cache_all_g_contacts' do
    it 'calls the api and caches all retrieved contacts' do
      api_user = double
      expect(account).to receive(:contacts_api_user).and_return(api_user)
      expect(api_user).to receive(:contacts).and_return([john1])

      expect(cache).to receive(:cache_g_contacts).with([john1], true)
      cache.cache_all_g_contacts
    end
  end

  describe 'cache_g_contacts' do
    it 'retrieves cached g_contacts; when set to cache all returns nil and not in cache' do
      cache.cache_g_contacts([john1, john2], true)

      expect(cache.find_by_id('john1')).to eq(john1)
      expect(cache.find_by_id('john2')).to eq(john2)
      expect(cache.find_by_id('not-john')).to be_nil

      expect(cache.query_by_full_name('John Doe')).to eq([john1, john2])
      expect(cache.query_by_full_name('Not-John')).to eq([])
    end

    it 'retrieves cached g_contacts; when not set to cache all, calls the api when not in cache' do
      cache.cache_g_contacts([john1, john2], false)
      expect(cache.find_by_id('john1')).to eq(john1)
      expect(cache.find_by_id('john2')).to eq(john2)

      api_user = double

      expect(account).to receive(:contacts_api_user).and_return(api_user)
      api_john = double
      expect(api_user).to receive(:get_contact).with('api_john').and_return(api_john)
      expect(api_john).to receive(:deleted?).and_return(false)
      expect(cache.find_by_id('api_john')).to eq(api_john)

      expect(account).to receive(:contacts_api_user).and_return(api_user)
      api_john_query = double
      expect(api_user).to receive(:query_contacts).with('Api John', showdeleted: false).and_return([api_john_query])
      expect(cache.query_by_full_name('Api John')).to eq([api_john_query])
    end
  end

  describe 'remove a contact from cache' do
    it 'allows you to remove a contact from the cache and then will call the api for get contact after that' do
      cache.cache_g_contacts([john1, john2], true)

      expect(cache.find_by_id('john1')).to eq(john1)
      expect(cache.find_by_id('john2')).to eq(john2)
      expect(cache.query_by_full_name('John Doe')).to eq([john1, john2])

      expect(cache.find_by_id('not-john')).to be_nil
      expect(cache.query_by_full_name('Not-John')).to eq([])

      cache.remove_g_contact(john1)

      expect(cache.find_by_id('john2')).to eq(john2)
      expect(cache.query_by_full_name('John Doe')).to eq([john2])

      api_user = double
      expect(account).to receive(:contacts_api_user).and_return(api_user)
      api_john1 = double
      expect(api_user).to receive(:get_contact).with('john1').and_return(api_john1)
      expect(api_john1).to receive(:deleted?).and_return(false)
      expect(cache.find_by_id('john1')).to eq(api_john1)
    end
  end
end
