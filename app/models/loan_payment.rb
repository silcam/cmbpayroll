class LoanPayment < ApplicationRecord
  belongs_to :loan

  validates :amount, numericality: { :greater_than_or_equal_to => 1 }
end
