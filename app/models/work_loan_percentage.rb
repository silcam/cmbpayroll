class WorkLoanPercentage < ApplicationRecord
  belongs_to :payslip
  belongs_to :department

  validates :percentage, presence: true
  validates :percentage, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
end
