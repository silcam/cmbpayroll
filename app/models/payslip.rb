class Payslip < ApplicationRecord

  VACATION_PAY = "Salaire de congé"
  MONTHLY = 12.0

  has_many :earnings
  has_many :deductions
  has_many :payslip_corrections
  has_many :work_loan_percentages

  belongs_to :employee

  validate :has_earnings?
  validates :period_year,
            :period_month,
               presence: {message: I18n.t(:Not_blank)}
  validates :net_pay, numericality: { :greater_than => 0, message: I18n.t(:Net_pay_error) }

  scope :for_period, ->(period) {
    where(period_year: period.year, period_month: period.month)
  }

  scope :posted, -> {
    period = LastPostedPeriod.current
    where("period_year < :year OR (period_year = :year AND period_month < :month)", {year: period.year, month: period.month})
    .order(period_year: :desc, period_month: :desc)
  }

  def previous
    period = Period.new(period_year, period_month).previous
    Payslip.find_by employee: employee, period_year: period.year, period_month: period.month
  end

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

    Employee.currently_paid.each do |emp|
      tmp_payslip = Payslip.process(emp, period)
      payslips.push(tmp_payslip) unless tmp_payslip.nil?
    end

    return payslips
  end

  # See the explanation in app/views/admin/estimate_pay.html.erb
  def self.compute_wage_from_departmental_charge(charge)
    charge -= SystemVariable.value(:emp_fund_amount)
    result = charge.fdiv(1 + SystemVariable.value(:dept_credit_foncier) +
        SystemVariable.value(:dept_cnps))

    if (result > SystemVariable.value(:cnps_ceiling))
      # recompute, to account for ceiling
      charge -= SystemVariable.value(:dept_cnps_max_base)
      result = charge.fdiv(1 + SystemVariable.value(:dept_credit_foncier) +
          SystemVariable.value(:dept_cnps_w_ceil))
    end

    wage = result * 0.72
    wage.floor
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

  def base_pay
    # If we have a bonus base, we've already run
    if (self[:bonusbase])
      return self[:basepay]
    end

    days_worked = WorkHour.days_worked(employee, period)
    hours_worked = WorkHour.hours_worked(employee, period)

    earning = Earning.new

    if (worked_full_month? && employee.paid_monthly?)
      earning.description = "Monthly Wages"
      earning.amount = employee.wage
    elsif (employee.paid_monthly? && days_worked > 0)
      earning.description = "Monthly wages less #{employee.workdays_per_month(period) - days_worked} days @ #{employee.daily_rate}"
      earning.rate = employee.daily_rate
      earning.amount = daily_earnings
    elsif (!employee.paid_monthly? && hours_worked > 0)
      earning.description = "Hourly earnings for #{hours_worked} hours"
      earning.rate = employee.hourly_rate
      earning.amount = hourly_earnings
    end

    if (earning.amount && earning.amount > 0)
      earnings << earning
      self[:basepay] = earning.amount
    else
      self[:basepay] = 0
    end
  end

  def worked_full_month?
    WorkHour.worked_full_month(employee, period)
  end

  def days_worked
    WorkHour.days_worked(employee, period)
  end

  def hours_worked
    WorkHour.hours_worked(employee, period)
  end

  def daily_earnings
    days_in_month = employee.workdays_per_month(period)
    days_worked = WorkHour.days_worked(employee, period)

    self[:days] = days_worked

    # NEW - compute pay based on removing working days * daily rate
    wage - ( ( days_in_month - days_worked ) * employee.daily_rate )
  end

  def hourly_earnings
    hours_worked = WorkHour.hours_worked(employee, period)

    self[:hours] = hours_worked

    hours_worked * employee.hourly_rate
  end

  def self.overtime_tranches(hours_hash)
    ot1_limit = SystemVariable.value :ot1_hours_limit
    ot2_limit = SystemVariable.value :ot2_hours_limit
    ot_tranches = {ot1: (hours_hash[:overtime] || 0), ot2: 0, ot3: (hours_hash[:holiday] || 0)}
    if ot_tranches[:ot1] > ot1_limit
      ot_tranches[:ot2] = ot_tranches[:ot1] - ot1_limit
      ot_tranches[:ot1] = ot1_limit
      if ot_tranches[:ot2] > ot2_limit
        ot_tranches[:ot3] += ot_tranches[:ot2] - ot2_limit
        ot_tranches[:ot2] = ot2_limit
      end
    end
    ot_tranches
  end

  def overtime_earnings
    # If we have a bonusbase, we've already run this.
    if (self[:bonusbase])
      return self[:overtime_earnings]
    end

    hours = WorkHour.total_hours(employee, period)
    ot_hours = Payslip.overtime_tranches hours

    ot1_earnings = ot_hours[:ot1] * employee.otrate
    ot2_earnings = ot_hours[:ot2] * employee.ot2rate
    ot3_earnings = ot_hours[:ot3] * employee.ot3rate

    # TODO: remove these columns
    self[:overtime_hours] = ot_hours[:ot1]
    self[:overtime2_hours] = ot_hours[:ot2]
    self[:overtime3_hours] = ot_hours[:ot3]
    self[:overtime_rate] = employee.otrate
    self[:overtime2_rate] = employee.ot2rate
    self[:overtime3_rate] = employee.ot3rate

    otearn = Earning.new(amount: ot1_earnings, description: "OT hours",
        hours: ot_hours[:ot1], rate: employee.otrate, overtime: true);
    ot2earn = Earning.new(amount: ot2_earnings, description: "OT2 hours",
        hours: ot_hours[:ot2], rate: employee.ot2rate, overtime: true);
    ot3earn = Earning.new(amount: ot3_earnings, description: "OT3 hours",
        hours: ot_hours[:ot3], rate: employee.ot3rate, overtime: true);

    earnings << otearn
    earnings << ot2earn
    earnings << ot3earn

    self[:overtime_earnings] = ot1_earnings + ot2_earnings + ot3_earnings
  end

  def compute_bonusbase
    self[:bonusbase] = ( base_pay + overtime_earnings ).ceil
  end

  def compute_caissebase
    self[:caissebase] = ( compute_bonusbase + seniority_bonus ).ceil
  end

  def compute_cnpswage
    self[:cnpswage] = ( compute_caissebase + process_bonuses + misc_pay ).ceil

    # NOTE: this previously used the Format(value, "0") VBA function, which I
    # intepreted as integer truncation.
    if (self[:cnpswage] > SystemVariable.value(:cnps_ceiling))
      self[:department_cnps] = ( self[:cnpswage] * SystemVariable.value(:dept_cnps_w_ceil) +
          SystemVariable.value(:dept_cnps_max_base) ).floor
    else
      self[:department_cnps] = ( self[:cnpswage] * SystemVariable.value(:dept_cnps) ).floor
    end

    self[:department_severance] = ( employee.department_severance_rate(period) * self[:cnpswage] ).floor

    self[:cnpswage]
  end

  def process_taxable_wage()
    transportation = employee.transportation ?
        employee.transportation : 0

    self[:taxable] = ( compute_cnpswage + transportation ).ceil

    # NOTE: this previously used the Format(value, "0") VBA function, which I
    # intepreted as integer truncation.
    self[:department_credit_foncier] = ( self[:taxable] *
        SystemVariable.value(:dept_credit_foncier) ).floor

    if (self[:taxable] > SystemVariable.value(:emp_fund_salary_floor))
      self[:employee_fund] = SystemVariable.value(:emp_fund_amount)
    else
      self[:employee_fund] = 0
    end
    # TODO: This is always zero, is this needed?
    self[:employee_contribution] = 0

    self[:gross_pay] = self[:taxable]
  end

  def process_taxes
    tax = Tax.compute_taxes(employee, taxable, cnpswage)

    self[:roundedpay] = Tax.roundpay(taxable)
    self[:crtv] = tax.crtv
    self[:ccf] = tax.ccf
    self[:proportional] = tax.proportional
    self[:cnps] = tax.cnps
    self[:cac] = tax.cac
    self[:cac2] = tax.cac2
    self[:communal] = tax.communal

    self[:total_tax] = tax.total_tax
  end

  # After all calculations, compute net pay from gross pay
  # less all deductions
  def compute_net_pay
    self[:raw_net_pay] = self[:gross_pay] - self[:total_tax] -
        total_deductions()

    if (self[:raw_net_pay] < 0)
      # This isn't good.
      # Set the net_pay to zero,  This will raise an error since
      # there's a model validation that net_pay must be greater
      # than zero.
      self[:net_pay] = 0
    else
      self[:net_pay] = Payslip.cfa_round(self[:raw_net_pay])
    end
  end

  def get_vacation_pay
    vac_pay = earnings.where(description: VACATION_PAY)&.first
    unless (vac_pay.nil?)
      vac_pay.amount
    else
      0
    end
  end

  def process_vacation_pay
    pay = calculate_vacation_pay(cnpswage, vacation_used)
    if pay > 0

      # TODO: is this right?
      #self[:taxable] += pay
      #self[:gross_pay] += pay

      earnings << Earning.new(description: VACATION_PAY, amount: pay)
    end
  end

  def compute_work_loans
    work_loans_by_dept = WorkLoan.work_loan_hash(employee, period)
    percentage_so_far = 0

    if (work_loans_by_dept.size > 0)
      hours_worked_this_month = WorkHour.hours_worked(employee, period)

      work_loans_by_dept.each do |dept,hours|
        wlp = WorkLoanPercentage.new
        percent_worked = hours.fdiv(hours_worked_this_month)
        wlp.percentage = percent_worked > 1 ? 1 : percent_worked

        found_dept = Department.find(dept)
        found_dept = employee.department if found_dept.nil?
        wlp.department_id = found_dept.id

        work_loan_percentages << wlp
        percentage_so_far += wlp.percentage
      end
    end

    balance = 1 - percentage_so_far
    if (balance > 0)
      wlp = WorkLoanPercentage.create(department_id: employee.department_id,
            percentage: balance)
      work_loan_percentages << wlp
    end
  end

  def bonus_total
    earnings.where(is_bonus: true).sum(:amount).floor
  end

  def store_employee_attributes
    self[:wage] = employee.wage
    self[:basewage] = employee.find_base_wage
    self[:transportation] = employee.transportation

    self[:category] = Employee.categories[employee.category]
    self[:echelon] = Employee.echelons[employee.echelon]
    self[:wagescale] = Employee.wage_scales[employee.wage_scale]

    self[:hourly_rate] = employee.hourly_rate
    self[:daily_rate] = employee.daily_rate
  end

  # Clear values and prepare for the payslip to be
  # reprocessed.
  def reset_payslip
    self[:wage] = nil
    self[:basewage] = nil
    self[:transportation] = nil

    self[:category] = nil
    self[:echelon] = nil
    self[:wagescale] = nil

    self[:hourly_rate] = nil
    self[:daily_rate] = nil

    self[:basepay] = nil
    self[:bonusbase] = nil
    self[:caissebase] = nil
    self[:cnpswage] = nil
    self[:taxable] = nil

    work_loan_percentages.delete_all
    earnings.delete_all
    deductions.delete_all
  end

  def seniority_bonus
    bonus = 0

    if (employee_eligible_for_seniority_bonus?)
      self[:years_of_service] = employee.years_of_service(period)
      self[:seniority_benefit] = SystemVariable.value(:seniority_benefit)

      bonus = employee.find_base_wage() *
          ( self[:seniority_benefit] * self[:years_of_service] )

      self[:seniority_bonus_amount] = bonus
    end

    bonus
  end

  private

  def self.process_payslip(employee, period, with_advance)
    # Do all the stuff that is needed to process a payslip for this user
    # TODO: more validation
    # TODO: Are there rules that the period must be
    #         the current period? (or the previous period)?

    # Is this correct behavior, or throw exception?
    return nil unless employee.is_currently_paid?

    employee.save

    payslip = Payslip.find_by(
                  employee_id: employee.id,
                  period_year: period.year,
                  period_month: period.month)

    if (payslip.nil?)
      payslip = employee.payslips.build(period_year: period.year,
        period_month: period.month, payslip_date: Date.today)
    end

    begin

      if (with_advance)
        self.process_advance(employee, period)
      end

      payslip.reset_payslip

      self.process_vacation(payslip, employee, period)
      self.process_earnings_and_taxes(payslip, employee, period)

      self.process_charges(payslip, employee)
      self.process_misc_payments(payslip, employee, period)
      self.process_employee_deductions(payslip, employee)
      self.process_loans(payslip, employee, period)
      self.process_payslip_corrections(payslip, employee, period)

      payslip.compute_work_loans
      payslip.compute_net_pay

      payslip.last_processed = DateTime.now
      payslip.save

    rescue Exception => e
      # raise e # Uncomment for easier debugging
      Rails.logger.error("Error processing payslip #{payslip.id} : #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      payslip.errors[:base] << e.message
    end

    return payslip
  end

  def process_bonuses
    # If we have a CNPS wage, we've already done this.
    if (self[:cnpswage])
      return self[:bonuspay]
    end

    base = caissebase
    bonus_total = 0

    employee.bonuses.all.each do |bonus|
      earning = Earning.new
      earning.description = bonus.name

      if (bonus.percentage?)
        earning.percentage = bonus.quantity
      end

      earning.amount = bonus.effective_bonus(base).floor
      earning.is_bonus = true
      earnings << earning

      bonus_total += earning.amount
    end

    self[:bonuspay] = bonus_total
  end

  def calculate_vacation_pay(cnpswage, vacation_used)
    days_earned = SystemVariable.value(:vacation_days) / MONTHLY
    vpay_factor = SystemVariable.value(:vacation_pay_factor)
    per_day = (cnpswage / days_earned) / vpay_factor
    (per_day * vacation_used).ceil
  end

  # def prev_vacation_pay_balance
  #   previous_slip = previous
  #   previous_slip.nil? ? 0 : previous_slip.vacation_pay_balance
  # end
  #
  # def calculate_vacation_pay_used
  #   days_used = Vacation.days_used employee, period
  #   previous_days_balance = Vacation.balance(employee, period.previous)
  #   previous_pay_balance = prev_vacation_pay_balance
  #   ((previous_pay_balance * days_used) / previous_days_balance).to_i
  # end
  #
  # def calculate_vacation_pay_balance
  #   prev_vacation_pay_balance +
  #     calculate_vacation_pay -
  #     calculate_vacation_pay_used
  # end

  def misc_pay
    # TODO Where does misc pay come from?
    0
  end

  def employee_eligible_for_seniority_bonus?
    employee.years_of_service(period) >=
        SystemVariable.value(:seniority_waiting_years)
  end

  def self.process_earnings_and_taxes(payslip, employee, period)
    payslip.store_employee_attributes
    payslip.process_taxable_wage
    payslip.process_vacation_pay
    payslip.process_taxes
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

  def self.process_misc_payments(payslip, employee, period)
    employee.misc_payments.for_period(period).each do |misc_payment|
      payslip.earnings << Earning.new(amount: misc_payment.amount, description: misc_payment.note)
    end
  end

  def self.process_employee_deductions(payslip, employee)
    expenses_hash = employee.deductable_expenses()

    expenses_hash.each do |k,v|
      amount = employee.send(v)

      if (amount && amount > 0)
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

  def self.process_vacation(payslip, employee, period)
    payslip.vacation_earned = Vacation.days_earned(employee, period)
    payslip.vacation_used = Vacation.days_used(employee, period)
    payslip.vacation_balance = Vacation.balance(employee, period)
    # payslip.vacation_pay_earned = payslip.calculate_vacation_pay
    # payslip.vacation_pay_used = payslip.calculate_vacation_pay_used
    # payslip.vacation_pay_balance = payslip.calculate_vacation_pay_balance

    last_vacation = employee.vacations.where('end_date <= ?', period.finish).last
    unless last_vacation.nil?
      payslip.last_vacation_start = last_vacation.start_date
      payslip.last_vacation_end = last_vacation.end_date
    end
  end

  def self.process_loans(payslip, employee, period)
    payments = LoanPayment.get_all_payments(employee, period)

    payments.each do |pmnt|
      next if pmnt.cash?

      deduction = Deduction.new

      deduction.note = LoanPayment::LOAN_PAYMENT_NOTE
      deduction.amount = pmnt.amount
      deduction.date = pmnt.date

      payslip.deductions << deduction
    end

    payslip.loan_balance = Loan.total_balance(employee)
  end

  def self.process_payslip_corrections(payslip, employee, period)
    corrections = employee.payslip_corrections.for_period(period)
    corrections.each do |correction|
      if correction.cfa_credit
        payslip.earnings << Earning.new(amount: correction.cfa_credit, description: "Correction pour le bulletin de #{correction.payslip.period} : #{correction.note}")
      elsif correction.cfa_debit
        payslip.deductions << Deduction.new(amount: correction.cfa_debit, date: period.finish, note: "Correction pour le bulletin de #{correction.payslip.period} : #{correction.note}")
      end

      unless correction.vacation_days == 0
        payslip.vacation_balance += correction.vacation_days
      end
    end
  end

  # Round to the next 5
  def self.cfa_round(input)
    ((input + 4) / 5).to_i * 5
  end

end
