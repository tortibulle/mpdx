def stub_auth
  stub_request(:get, "http://oauth.ccci.us/users/"+user.access_token).
     to_return(:status => 200)
end
