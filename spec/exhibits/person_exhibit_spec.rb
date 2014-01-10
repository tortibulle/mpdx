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

    it 'should make facebook image' do
      person.stub(facebook_account: double(remote_id: 1234),
                  primary_picture: double(image: double(url: nil))
      )
      expect(exhib.avatar).to eq('https://graph.facebook.com/1234/picture?type=square')
    end
  end

end
