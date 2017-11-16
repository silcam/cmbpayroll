class PayslipCorrection < ApplicationRecord
  belongs_to :payslip
  has_one :employee, through: :payslip

  validates :cfa, numericality: {only_integer: true}
  validates :vacation_days, numericality: true

  def self.current
    current_period = LastPostedPeriod.current
    where(applied_year: current_period.year, applied_month: current_period.month)
  end

  def cfa_credit
    cfa if cfa > 0
  end

  def cfa_debit
    cfa * -1 if cfa < 0
  end

  def vacation_days_credit
    vacation_days if vacation_days > 0
  end

  def vacation_days_debit
    vacation_days * -1 if vacation_days < 0
  end

  def self.new(params={})
    period = LastPostedPeriod.current
    params.merge! applied_year: period.year, applied_month: period.month
    super params
  end
end
