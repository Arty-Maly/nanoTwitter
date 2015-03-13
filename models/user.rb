class User < ActiveRecord::Base
has_many :tweets, dependent: :destroy
attr_accessor :password
  # validates_confirmation_of :password
  validates_presence_of :password
  before_save :encrypt_password


  def encrypt_password
    self.password_salt = BCrypt::Engine.generate_salt
    self.password_hash = BCrypt::Engine.hash_secret(password, password_salt)
  end

def self.authenticate(handle, password)
    user = User.where(handle: handle).first
    if user && user.password_hash == BCrypt::Engine.hash_secret(password, user.password_salt)
      user
    else
      nil
    end
  end

end