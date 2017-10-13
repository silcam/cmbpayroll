class User < ApplicationRecord
  include BelongsToPerson

  has_secure_password

  validates :username, :role, presence: {message: I18n.t(:Not_blank)}

  enum language: [:en, :fr]

  enum role: { user: 0, supervisor: 1, admin: 2 }

end
