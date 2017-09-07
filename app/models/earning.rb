class Earning < ApplicationRecord
  belongs_to :payslip

  validate :either_amount_or_rate

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

  def either_amount_or_rate
    if (!has_valid_amount() && !has_valid_hourly_rate())
      errors.add(:amount, "must have fixed amount or an hourly rate with hours")
      errors.add(:rate, "must have fixed amount or an hourly rate with hours")
    end
  end

  private

  def has_valid_amount
    unless (amount.nil? || amount < 0)
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
