class SupplementalTransfer < ApplicationRecord

  belongs_to :employee

  validates :transfer_date, presence: true

  default_scope { order(transfer_date: :desc) }

end
