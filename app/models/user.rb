class User < ApplicationRecord
  include BelongsToPerson

  belongs_to :person

  has_secure_password

  validates :username, presence: {message: I18n.t(:Not_blank)}
end
