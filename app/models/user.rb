class User < ApplicationRecord
  include BelongsToPerson

  has_secure_password

  validates :username, :role, presence: {message: I18n.t(:Not_blank)}

  enum language: { en: 0, fr: 1 }

  # TODO FIXME possibly need to add supervisor here.
  # check against test failures.
  #
  # 3. Enum Changes (The Most Likely Culprit)
  # If role is an Enum in your model, Rails 6.1 is stricter about how it handles nulls vs. defaults. If you have:
  #
  # Ruby
  # enum role: { admin: 0, user: 1 }
  # And you don't provide a default in the migration or the model, Ruby 3.2 might be passing a nil where Rails 5 used to silently ignore it.
  #
  # The Fix:
  # Check the WorkHour model. If role is an enum, add a default:
  #
  # Ruby
  # enum role: { admin: 0, user: 1 }, _default: :user
  #
  #
  #
  enum role: { user: 0, admin: 2 }

  def supervisor?
    not person.supervisor.nil?
  end
end
