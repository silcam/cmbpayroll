class Loan < ApplicationRecord
  belongs_to :employee

  has_many :loan_payments, :before_add => :validate_cannot_overpay_loan

  validates :term, presence: true
  validates :origination, presence: true
  validates :amount, numericality: { :greater_than_or_equal_to => 1 }
  validate :not_in_posted_period

  enum term: [ :six_month_term, :eight_month_term ]

  default_scope { order(origination: :asc) }

  def self.total_amount(employee)
    total_amount = 0

    employee.loans.each do |loan|
      next if loan.is_paid()

      total_amount += loan.amount
    end

    total_amount
  end

  def self.total_balance(employee)
    total_balance = 0

    employee.loans.each do |loan|
      next if loan.is_paid()

      loan_sum = loan.amount
      payments_sum = loan.loan_payments.all().sum(:amount)

      total_balance += (loan_sum - payments_sum)
    end

    total_balance
  end

  def self.paid_loans(employee)
    loans = []

    employee.loans.each do |loan|
      next unless loan.is_paid()
      loans << loan
    end

    loans
  end

  def self.unpaid_loans(employee)
    loans = []

    employee.loans.each do |loan|
      next if loan.is_paid()
      loans << loan
    end

    loans
  end

  def destroyable?
    true if not_in_posted_period
  end

  def destroy
    super if destroyable?
  end

  def is_paid
    if (balance() == 0)
      return true
    else
      return false
    end
  end

  def balance
    amount - loan_payments.all().sum(:amount)
  end

  private

  def not_in_posted_period
    if origination.present? && origination <= LastPostedPeriod.get.finish
      errors.add :date, I18n.t(:cant_be_during_posted_period)
      false
    else
      true
    end
  end

  def validate_cannot_overpay_loan(loan_payment)
    if (loan_payment.amount && (balance() - loan_payment.amount < 0))
      loan_payment.errors.add(:amount, "cannot over pay loan.  Current balance is: #{balance}")
      raise ActiveRecord::RecordInvalid.new(loan_payment)
    end
  end

end
