class Supervisor < ApplicationRecord
  include BelongsToPerson

  has_many :employees
end
