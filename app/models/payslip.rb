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

  def self.process(employee, period=Period.current)
    return self.process_payslip(employee, period, false)
  end

  def self.process_with_advance(employee, period=Period.current)
    return self.process_payslip(employee, period, true)
  end

  def self.process_all(period)
    payslips = Array.new

    Employee.all.each do |emp|
      tmp_payslip = Payslip.process(emp, period)
      payslips.push(tmp_payslip)
    end

    return payslips
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


  private

  def self.process_payslip(employee, period, with_advance)
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

    if (with_advance)
      self.process_advance(employee, period)
    end

    payslip.earnings.delete_all
    self.process_hours(payslip, employee, period)
    self.process_bonuses(payslip, employee)

    payslip.deductions.delete_all
    self.process_charges(payslip, employee)
    self.process_employee_deduction(payslip, employee)

    payslip.last_processed = DateTime.now

    employee.payslips << payslip

    return payslip
  end


  def self.process_hours(payslip, employee, period)
    hours = WorkHour.total_hours(employee, period)

    hours.each do |key, value|
      earning = Earning.new
      earning.rate = employee.wage
      earning.hours = value

      if (key == :holiday)
        earning.overtime = true
      end

      payslip.earnings << earning
    end
  end

  # TODO: does this need to know about
  # the period and recreate bonuses at the
  # time?  Right now this only processed
  # bonuses for today regardless of the
  # requested period
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
    end
  end

  def self.process_charges(payslip, employee)
    employee.charges.each do |charge|
      next if (charge.date < payslip.period.start ||
                  charge.date > payslip.period.finish)

      deduction = Deduction.new

      deduction.note = charge.note
      deduction.amount = charge.amount
      deduction.date = charge.date

      payslip.deductions << deduction
    end
  end

  def self.process_employee_deduction(payslip, employee)
    expenses_hash = employee.deductable_expenses()

    expenses_hash.each do |k,v|
      amount = employee.send(v)

      if (amount > 0)
        deduction = Deduction.new

        deduction.note = k
        deduction.amount = amount
        deduction.date = payslip.period.start

        payslip.deductions << deduction
      end
    end
  end

  def self.process_advance(employee, period)
    return if (employee.has_advance_charge(period))

    charge = Charge.new
    charge.date = period.mid_month()
    charge.amount = employee.advance_amount()
    charge.note = Charge::ADVANCE

    employee.charges << charge
  end
end
