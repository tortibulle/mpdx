require 'spec_helper'
require 'capybara/rspec'

describe 'create new contact', type: :feature do
  before :each do
    user = create(:user_with_account)
    login(user)
  end

  it 'saves' do
    contact = build(:contact)
    visit '/contacts/new'
    within('#new_contact') do
      fill_in 'Name', with: contact.name
      fill_in 'First name', with: contact.name
    end
    first(:button, 'Save Contact').click
    expect(page).to have_title contact.name
  end
end
