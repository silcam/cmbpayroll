class Supervisor < ApplicationRecord
  include BelongsToPerson

  has_many :employees, dependent: :restrict_with_exception
end
