class Deduction < ApplicationRecord

  belongs_to :payslip

  # :note (String)
  # :amount (decimal)
  # :date (DateTime)

  validates :note, :amount, :date, presence: {message: I18n.t(:Not_blank)}
  validate :date_is_valid_for_payslip

  private

  def date_is_valid_for_payslip
    period = payslip.period

    unless (period.nil?)
      unless (period.start <= date && date <= period.finish)
        errors.add(:date, "date of deduction must be within payslip period")
      end
    end
  end

end
