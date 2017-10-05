class Department < ApplicationRecord
  has_many :employees
  has_many :work_loans
end
