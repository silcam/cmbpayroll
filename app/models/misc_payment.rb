class MiscPayment < ApplicationRecord
  validates :amount, numericality: {only_integer: true}

  belongs_to :employee
end
