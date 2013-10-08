require 'spec_helper'
describe PersonExhibit do

  let(:exhib) { PersonExhibit.new(person, context) }
  let(:person) { build(:person)}
  let(:context) { double }

  context '#avatar' do
    it 'should ignore images with nil content' do
      person.stub(facebook_account: nil,
                  primary_picture: double(image: double(url: nil)),
                  gender: nil
      )
      expect(exhib.avatar).to eq('https://mpdx.org/assets/avatar.png')
    end
  end

end
