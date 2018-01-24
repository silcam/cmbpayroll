class LoanPayment < ApplicationRecord
  belongs_to :loan

  LOAN_PAYMENT_NOTE="Loan Payment"

  validates :amount, numericality: { :greater_than_or_equal_to => 1 }
  validates :date, presence: true
  validate :not_in_posted_period

  default_scope { order(:date) }

  def self.get_all_payments(employee, period)
    raise ArgumentError if employee.nil? || period.nil?

    joins(:loan).
      where(date: period.start..period.finish, 'loans.employee_id': employee.id)
  end

  def destroyable?
    true if not_in_posted_period
  end

  def destroy
    super if destroyable?
  end

  def cash?
    self[:cash_payment]
  end

  private

  def not_in_posted_period
    return false unless date.present?
    if date <= LastPostedPeriod.get.finish
      errors.add :date, I18n.t(:cant_be_during_posted_period)
      false
    else
      true
    end
  end
end
