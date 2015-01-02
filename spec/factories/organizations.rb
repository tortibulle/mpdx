# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  sequence :query_ini_url do |n|
    n
  end
  factory :organization do
    name 'MyString'
    query_ini_url { FactoryGirl.generate(:query_ini_url) }
    api_class 'DataServer'
    profiles_url 'http://example.com/profiles'
    profiles_params 'UserName=test@test.com&Password=Test1234&Action=Profiles'
    addresses_url 'http://example.com/addresses'
    addresses_params 'UserName=$ACCOUNT$&Password=$PASSWORD$&Profile=$PROFILE$&DateFrom=$DATEFROM$&Action=Donors'
    donations_url 'http://example.com/donations'
    donations_params 'UserName=$ACCOUNT$&Password=$PASSWORD$&Profile=$PROFILE$&DateFrom=$DATEFROM$&DateTo=$DATETO$&Action=Gifts'
    account_balance_url 'http://example.com/accounts'
    account_balance_params 'UserName=$ACCOUNT$&Password=$PASSWORD$&Profile=$PROFILE$&Action=AccountBalance'

  end

  factory :ccc, parent: :organization do
    name 'Cru - USA'
    code 'CCC-USA'
    api_class 'Siebel'
    profiles_params 'Action=Profiles'
    addresses_params 'Profile=$PROFILE$&DateFrom=$DATEFROM$&Action=Donors'
    donations_params 'Profile=$PROFILE$&DateFrom=$DATEFROM$&DateTo=$DATETO$&Action=Gifts'
    account_balance_params 'Profile=$PROFILE$&Action=AccountBalance'
  end

  factory :fake_org, parent: :organization do
    api_class 'FakeApi'
  end

  factory :nav, parent: :organization do
    api_class 'DataServerNavigators'
    account_balance_params 'UserName=$ACCOUNT$&Password=$PASSWORD$'
  end

  factory :offline_org, parent: :organization do
    api_class 'OfflineOrg'
    profiles_url nil
  end
end
