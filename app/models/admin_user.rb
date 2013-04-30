class AdminUser < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable

  devise :token_authenticatable, :trackable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :guid

  def to_s
    email
  end
end
