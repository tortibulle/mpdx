# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  sequence :query_ini_url do |n|
    n
  end
  factory :organization do
    name "MyString"
    query_ini_url {FactoryGirl.generate(:query_ini_url)}
    api_class 'DataServer'
    profiles_url 'http://example.com/'
    profiles_params 'UserName=test@test.com&Password=Test1234&Action=Profiles'
    addresses_url 'http://example.com/'
    addresses_params 'UserName=$ACCOUNT$&Password=$PASSWORD$&Profile=$PROFILE$&DateFrom=$DATEFROM$&Action=Donors'
    donations_url 'http://example.com/'
    donations_params 'UserName=$ACCOUNT$&Password=$PASSWORD$&Profile=$PROFILE$&DateFrom=$DATEFROM$&DateTo=$DATETO$&Action=Gifts'
    account_balance_url 'http://example.com/'
    account_balance_params 'UserName=$ACCOUNT$&Password=$PASSWORD$&Profile=$PROFILE$&Action=AccountBalance'

  end
  

  factory :ccc, parent: :organization do
    name "Campus Crusade for Christ - USA"
    api_class 'SiebelTemp'
    profiles_params 'Action=Profiles'
    addresses_params 'Profile=$PROFILE$&DateFrom=$DATEFROM$&Action=Donors'
    donations_params 'Profile=$PROFILE$&DateFrom=$DATEFROM$&DateTo=$DATETO$&Action=Gifts'
    account_balance_params 'Profile=$PROFILE$&Action=AccountBalance'
  end

  factory :fake_org, parent: :organization do
    api_class 'FakeApi'
  end
end
