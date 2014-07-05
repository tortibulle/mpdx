class SessionsController < Devise::SessionsController
  skip_before_action :ensure_login, :ensure_setup_finished
end
