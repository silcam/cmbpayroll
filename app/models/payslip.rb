class Payslip < ApplicationRecord

  has_many :earnings
  has_many :deductions
  has_many :withholdings
  has_many :payments

  belongs_to :employee

  validate :has_earnings?
  validates :period_year,
            :period_month,
            :payslip_date,
               presence: {message: I18n.t(:Not_blank)}

  def has_earnings?
    # query these items to see if there are any.
    if (self.earnings.empty?)
      self.errors.add(:earnings, "Must have earnings to process")
      return false
    else
      return true
    end
  end

  def total_earnings
    if (earnings.empty?)
      return 0
    end

    tmp_total = 0

    earnings.each do |record|
      tmp_total += record.total() if record.valid?
    end

    return tmp_total
  end

  def period
    if (period_year && period_month)
      return Period.new(period_year, period_month)
    else
      return nil
    end
  end

  def self.process(employee, period)
    # Do all the stuff that is needed to process a payslip for this user
    # TODO: more validation
    # TODO: Are there rules that the period must be
    #         the current period? (or the previous period)?

    payslip = Payslip.find_by(
                  period_year: period.year,
                  period_month: period.month)

    if (payslip.nil?)
      payslip = Payslip.new

      payslip.period_year = period.year
      payslip.period_month = period.month

      payslip.payslip_date = Date.today
    end

    # TODO: do this?
    payslip.earnings.delete_all

    self.process_hours(payslip, employee, period)
    self.process_bonuses(payslip, employee)

    payslip.last_processed = DateTime.now

    payslip.save
    employee.save

    employee.payslips << payslip

    return payslip
  end

  # TODO: is this needed anymore?
  # TODO: maybe call this 'total'?
  def process
    unless (self.valid?)
        return
    end

    # do other things, but that's all for now.
    if (self.last_processed.nil?)
        self.last_processed = DateTime.now
    end
  end

  private

  def self.process_hours(payslip, employee, period)
    hours = WorkHour.total_hours(employee, period)

    hours.each do |key, value|
      earning = Earning.new
      earning.rate = employee.wage
      earning.hours = value

      if (key == :overtime)
        earning.overtime = true
      end

      earning.save
      payslip.earnings << earning
    end
  end

  def self.process_bonuses(payslip, employee)

    employee.bonuses.each do |emp_bonus|

      earning = Earning.new
      earning.description = emp_bonus.name
      if (emp_bonus.bonus_type == "percentage")
        earning.percentage = emp_bonus.quantity
      else
        earning.amount = emp_bonus.quantity
      end

      earning.save
      payslip.earnings << earning
    end
  end

end
