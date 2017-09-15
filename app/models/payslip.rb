class Payslip < ApplicationRecord

  has_many :earnings
  has_many :deductions

  belongs_to :employee

  validate :has_earnings?
  validates :period_year,
            :period_month,
            :payslip_date,
               presence: {message: I18n.t(:Not_blank)}


  def self.current_period
    return self.from_period( Period.current)
  end

  def self.from_period( period )
    payslip = Payslip.new
    payslip.period_year = period.year
    payslip.period_month = period.month
    return payslip
  end

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

  def total_deductions
    if (deductions.empty?)
      return 0
    end

    tmp_total = 0

    deductions.each do |record|
      tmp_total += record.amount() if record.valid?
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

  def self.process_all(period)
    payslips = Array.new

    Employee.all.each do |emp|
      tmp_payslip = Payslip.process(emp, period)
      payslips.push(tmp_payslip)
    end

    return payslips
  end

  def self.process(employee, period)
    # Do all the stuff that is needed to process a payslip for this user
    # TODO: more validation
    # TODO: Are there rules that the period must be
    #         the current period? (or the previous period)?

    payslip = Payslip.find_by(
                  employee_id: employee.id,
                  period_year: period.year,
                  period_month: period.month)

    if (payslip.nil?)
      payslip = Payslip.new

      payslip.period_year = period.year
      payslip.period_month = period.month

      payslip.payslip_date = Date.today
    end

    payslip.earnings.delete_all
    self.process_hours(payslip, employee, period)
    self.process_bonuses(payslip, employee)

    payslip.deductions.delete_all
    self.process_deductions(payslip, employee)

    payslip.last_processed = DateTime.now

    employee.payslips << payslip

    #payslip.save
    #employee.save

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

      payslip.earnings << earning
      #earning.save
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

      payslip.earnings << earning
      #earning.save
    end
  end

  def self.process_deductions(payslip, employee)
    employee.charges.each do |charge|

      next if (charge.date < payslip.period.start ||
                  charge.date > payslip.period.finish)

      deduction = Deduction.new

      deduction.note = charge.note
      deduction.amount = charge.amount
      deduction.date = charge.date

      payslip.deductions << deduction
      #deduction.save
    end
  end

end
