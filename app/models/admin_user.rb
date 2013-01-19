class AdminUser < ActiveRecord::Base
  devise :token_authenticatable, :trackable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :guid

  def to_s
    email
  end
end
