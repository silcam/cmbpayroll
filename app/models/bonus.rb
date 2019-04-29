include ActionView::Helpers::NumberHelper

class Bonus < ApplicationRecord

  has_and_belongs_to_many :employees

  validates :name, :quantity, :bonus_type, presence: {message: I18n.t(:Not_blank)}
  validates :maximum, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :minimum, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :appropriate_quantities_per_type
  validate :min_and_max_only_with_percentage
  validate :min_less_than_max

  def appropriate_quantities_per_type
    if (quantity.nil? || !quantity.is_a?(Numeric) ||
        !ext_quantity.is_a?(Numeric))
      errors.add(:quantity, I18n.t(:Must_be_a_number))
    elsif (is_percentage_bonus?)
      if (quantity <= 0.0 || quantity > 1.0)
        errors.add(:quantity, I18n.t(:Must_be_between_zero_and_one_hundred))
      end
    elsif (fixed?)
      if (quantity <= 0 || quantity % 1 != 0)
        errors.add(:quantity, I18n.t(:Must_be_whole_number))
      end
    end
  end

  def min_and_max_only_with_percentage
    if (maximum && bonus_type == "fixed")
      errors.add(:maximum, I18n.t(:Only_with_percentage))
    elsif (minimum && bonus_type == "fixed")
      errors.add(:minimum, I18n.t(:Only_with_percentage))
    end
  end

  def min_less_than_max
    if (maximum && minimum && maximum < minimum)
      errors.add(:maximum, I18n.t(:Maximum_must_be_greater))
      errors.add(:minimum, I18n.t(:Minimum_must_be_less))
    end
  end

  enum bonus_type: { percentage: 0, fixed: 1, base_percentage: 2 }

  def ext_quantity
    if is_percentage_bonus?
      quantity * 100.0
    else
      quantity.to_i
    end
  end

  def ext_quantity=(qty)
    if is_percentage_bonus?
      self.quantity = qty.to_f / 100.0
    else
      self.quantity = qty.to_i
    end
  end

  def display_quantity
    if is_percentage_bonus?
       number_to_percentage(quantity * 100, precision: 5, strip_insignificant_zeros: true)
    else
       number_to_currency(quantity, locale: :cm)
    end
  end

  def effective_bonus(salary)
    if is_percentage_bonus?
      result = salary * quantity

      if (minimum && result < minimum)
        minimum
      elsif (maximum && result > maximum)
        maximum
      else
        result
      end
    else
      quantity
    end
  end

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

  def is_percentage_bonus?
    if bonus_type == "percentage" || bonus_type == "base_percentage"
      return true
    else
      return false
    end
  end

end
