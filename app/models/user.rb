class User < ApplicationRecord
  include BelongsToPerson

  has_secure_password

  validates :username, presence: {message: I18n.t(:Not_blank)}
end
