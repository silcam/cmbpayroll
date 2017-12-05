class Department < ApplicationRecord

  has_many :employees
  has_many :work_loans
  has_many :work_loan_percentages

end
