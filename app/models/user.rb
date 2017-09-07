class User < ApplicationRecord
  include BelongsToPerson

  belongs_to :person

  validates :username, :password, presence: {message: I18n.t(:Not_blank)}
end
