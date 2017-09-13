class Earning < ApplicationRecord
  belongs_to :payslip

  validate :has_amount_percentage_or_rate

  # :description
  # :rate
  # :hours
  # :fixed_amount
  # :overtime (boolean)

  def total
    unless (valid?)
        raise "Cannot total an invalid Earning: r: #{rate}, h: #{hours}"
    end

    if (has_valid_amount)
        return amount
    else
        return hours * rate
    end
  end

  def has_amount_percentage_or_rate
    unless (has_valid_amount() || has_valid_hourly_rate() || has_valid_percentage())
      errors.add(:percentage, "must have percentage, amount or an hourly rate with hours")
    end
  end

  private

  def has_valid_amount
    unless (amount.nil? || amount <= 0)
      return true
    else
      return false
    end
  end

  def has_valid_percentage
    unless (percentage.nil? || percentage <= 0)
      return true
    else
      return false
    end
  end

  def has_valid_hourly_rate
    unless ((hours.nil? || hours < 0) || (rate.nil? || rate < 0))
      return true
    else
      return false
    end
  end

end
