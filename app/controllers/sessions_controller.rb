class SessionsController < Devise::SessionsController
  skip_before_filter :ensure_login, :ensure_setup_finished

end
