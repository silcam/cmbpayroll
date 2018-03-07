include ActionView::Helpers::NumberHelper

class Bonus < ApplicationRecord

  has_and_belongs_to_many :employees

  validates :name, :quantity, :bonus_type, presence: {message: I18n.t(:Not_blank)}
  validates :maximum, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :appropriate_quantities_per_type
  validate :maximum_only_with_percentage

  def appropriate_quantities_per_type
    if (quantity.nil? || !quantity.is_a?(Numeric) ||
        !ext_quantity.is_a?(Numeric))
      errors.add(:quantity, I18n.t(:Must_be_a_number))
    elsif (percentage?)
      if (quantity <= 0.0 || quantity > 1.0)
        errors.add(:quantity, I18n.t(:Must_be_between_zero_and_one_hundred))
      end
    elsif (fixed?)
      if (quantity <= 0 || quantity % 1 != 0)
        errors.add(:quantity, I18n.t(:Must_be_whole_number))
      end
    end
  end

  def maximum_only_with_percentage
    if (maximum && bonus_type == "fixed")
      errors.add(:maximum, I18n.t(:Only_with_percentage))
    elsif (maximum && bonus_type == "percentage")
      if (maximum <= 0 || maximum % 1 != 0)
        errors.add(:maximum, I18n.t(:Must_be_whole_number))
      end
    end
  end

  enum bonus_type: { percentage: 0, fixed: 1 }

  def ext_quantity
    if (bonus_type == "percentage")
      quantity * 100.0
    else
      quantity.to_i
    end
  end

  def ext_quantity=(qty)
    if (bonus_type == "percentage")
      self.quantity = qty.to_f / 100.0
    else
      self.quantity = qty.to_i
    end
  end

  def display_quantity
    if (bonus_type == "percentage")
       number_to_percentage(quantity * 100, precision: 5, strip_insignificant_zeros: true)
    else
       number_to_currency(quantity, locale: :cm)
    end
  end

  def effective_bonus(salary)
    if (bonus_type == "percentage")
      result = salary * quantity

      if (maximum && result > maximum)
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

end
