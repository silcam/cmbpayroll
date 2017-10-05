include ActionView::Helpers::NumberHelper

class Bonus < ApplicationRecord

  has_and_belongs_to_many :employees

  validates :name, :quantity, :bonus_type, presence: {message: I18n.t(:Not_blank)}
  validate :appropriate_quantities_per_type

  def appropriate_quantities_per_type
    if (quantity.nil? || !quantity.is_a?(Numeric))
      errors.add(:quantity, "must be a number")
    elsif (percentage?)
      if (quantity > 100.0 || quantity <= 0.0)
        errors.add(:quantity, "invalid percentage quantity")
      end
    elsif (fixed?)
      if (quantity <= 0 || quantity % 1 != 0)
        errors.add(:quantity, "invalid fixed quantity")
      end
    end
  end

  enum bonus_type: [ :percentage, :fixed ]

  # TODO: still probably not perfect.
  def display_quantity
    if (bonus_type == "percentage")
       return number_to_percentage(quantity, precision: 4)
    else
       return number_to_currency(quantity, locale: :cm)
    end
  end

  #
  # Should receive a hash of the form
  #     { "222" => 1 }
  # Where checked bonuses are in the hash
  # and unchecked bonuses are not
  #
  def self.assign_to_employee(employee, bonus_hash)
    if bonus_hash.nil?
      employee.bonuses.clear
    else
      new_bonuses = Bonus.where(id: bonus_hash.keys)
      employee.bonuses = new_bonuses
    end
  end

end
