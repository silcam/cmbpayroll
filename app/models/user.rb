class User < ApplicationRecord
  include BelongsToPerson

  has_secure_password

  validates :username, :role, presence: {message: I18n.t(:Not_blank)}

  enum language: { en: 0, fr: 1 }
  enum role: { user: 0, admin: 2 }

  def supervisor?
    not person.supervisor.nil?
  end
end
