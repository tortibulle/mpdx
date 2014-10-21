describe GoogleContactsCache do
  # describe 'get_or_query_g_contact' do
  #   it 'gets the g_contact if there is a remote_id in the passed google contact link record' do
  #     expect(@integrator).to receive(:get_g_contact).with('1').and_return('g contact')
  #     expect(@integrator.get_or_query_g_contact(double(remote_id: '1'), @person)).to eq('g contact')
  #   end
  #
  #   it 'queries the g_contact if there is no remote_id in the passed google contact link record' do
  #     expect(@integrator).to receive(:query_g_contact).with(@person).and_return('g contact')
  #     expect(@integrator.get_or_query_g_contact(double(remote_id: nil), @person)).to eq('g contact')
  #   end
  # end
  #
  # describe 'get_g_contact' do
  #   before do
  #     @api_user = @account.contacts_api_user
  #   end
  #
  #   it 'calls the api if there are no cached contacts' do
  #     expect(@api_user).to receive(:get_contact).with('id').and_return('g_contact')
  #     expect(@integrator.get_g_contact('id')).to eq('g_contact')
  #   end
  #
  #   it 'uses the cache if there is a matching cached contact' do
  #     g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
  #     @integrator.cache_g_contacts([g_contact], false)
  #     expect(@api_user).to receive(:get_contact).exactly(0).times
  #     expect(@integrator.get_g_contact('id')).to eq(g_contact)
  #   end
  #
  #   it 'calls the api if there is no matching cached contact' do
  #     g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
  #     @integrator.cache_g_contacts([g_contact], false)
  #     expect(@api_user).to receive(:get_contact).with('non-cached-id').and_return('api_g_contact')
  #     expect(@integrator.get_g_contact('non-cached-id')).to eq('api_g_contact')
  #   end
  #
  #   it 'calls the api if the cache is cleared' do
  #     g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
  #     @integrator.cache_g_contacts([g_contact], false)
  #     @integrator.clear_g_contact_cache
  #
  #     expect(@api_user).to receive(:get_contact).with('id').and_return('api_g_contact')
  #     expect(@integrator.get_g_contact('id')).to eq('api_g_contact')
  #   end
  # end
  #
  # describe 'query_g_contact' do
  #   before do
  #     @api_user = @account.contacts_api_user
  #     @integrator.assigned_remote_ids = [].to_set
  #   end
  #
  #   it 'queries by first and last name returns nil if no results from api query' do
  #     expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([])
  #     expect(@integrator.query_g_contact(@person)).to be_nil
  #   end
  #
  #   it 'queries by first and last name returns nil if there are results with different name' do
  #     g_contact = double(given_name: 'Not-John', family_name: 'Doe')
  #     expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([g_contact])
  #     expect(@integrator.query_g_contact(@person)).to be_nil
  #   end
  #
  #   it 'queries by first and last name returns match if there are results with same name' do
  #     g_contact = double(given_name: 'John', family_name: 'Doe', id: '1')
  #     expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([g_contact])
  #     expect(@integrator.query_g_contact(@person)).to eq(g_contact)
  #   end
  #
  #   it 'uses the cache if there is a matching cached contact' do
  #     g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
  #     @integrator.cache_g_contacts([g_contact], false)
  #
  #     expect(@api_user).to receive(:query_contacts).exactly(0).times
  #     expect(@integrator.query_g_contact(@person)).to eq(g_contact)
  #   end
  #
  #   it 'calls the api if there is no matching cached contact, and not all g_contacts are cached' do
  #     cached_g_contact = double(id: 'id', given_name: 'Not-John', family_name: 'Not-Doe')
  #     @integrator.cache_g_contacts([cached_g_contact], false)
  #
  #     api_g_contact =  double(id: 'api_id', given_name: 'John', family_name: 'Doe')
  #     expect(@api_user).to receive(:query_contacts).with('John Doe').and_return([api_g_contact])
  #     expect(@integrator.query_g_contact(@person)).to eq(api_g_contact)
  #   end
  #
  #   it "doesn't call the api if there is no matching cached contact and we specified that all g_contacts are cached" do
  #     cached_g_contact = double(id: 'id', given_name: 'Not-John', family_name: 'Not-Doe')
  #     @integrator.cache_g_contacts([cached_g_contact], true)
  #     expect(@api_user).to receive(:query_contacts).exactly(0).times
  #     expect(@integrator.query_g_contact(@person)).to be_nil
  #   end
  #
  #   it "doesn't return a matching g_contact if that g_contact's remote_id is already assigned" do
  #     @integrator.assigned_remote_ids = ['already_assigned'].to_set
  #
  #     g_contact =  double(id: 'already_assigned', given_name: 'John', family_name: 'Doe')
  #     expect(@integrator).to receive(:lookup_g_contacts_for_name).with('John Doe').and_return([g_contact])
  #     expect(@integrator.query_g_contact(@person)).to be_nil
  #   end
  #
  #   it "doesn't fail if no first or last name" do
  #     expect(@api_user).to receive(:query_contacts).with(' ').and_return([])
  #     @person.first_name = nil
  #     @person.last_name = nil
  #     expect(@integrator.query_g_contact(@person)).to be_nil
  #   end
  # end
end
