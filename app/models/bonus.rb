class Bonus < ApplicationRecord

  validates :name, :quantity, :bonus_type, presence: {message: I18n.t(:Not_blank)}
  validates :quantity, numericality: { greater_then: 0.0 }

  enum bonus_type: [ :percentage, :fixed ]

end
