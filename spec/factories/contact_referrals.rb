# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :contact_referral do
    referred_by nil
    referred_contact nil
  end
end
