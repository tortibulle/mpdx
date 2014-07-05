class MonitorsController < ApplicationController
  skip_before_filter :ensure_login
  skip_before_filter :ensure_setup_finished
  layout nil
  newrelic_ignore

  def lb
    ActiveRecord::Base.connection.select_values('select id from people limit 1')
    render text: File.read(Rails.public_path.join('lb.txt'))
  end
end

