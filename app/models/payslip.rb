class Payslip < ApplicationRecord

  VACATION_PAY = "Salaire de congé"
  LOCATION_TRANSFER = "Salary Transfer to"
  STANDARD_DAYS_EARNED = SystemVariable.value(:vacation_days).fdiv(Vacation::MONTHLY)

  has_many :earnings, dependent: :destroy
  has_many :deductions, dependent: :destroy
  has_many :payslip_corrections
  has_many :work_loan_percentages

  belongs_to :employee

  validate :has_earnings?
  validates :period_year,
            :period_month, presence: {message: I18n.t(:Not_blank)}
  validates :net_pay, numericality: {
              :greater_than_or_equal_to => -4,
              message: I18n.t(:Net_pay_error)
  }

  scope :for_period, ->(period) {
    where(period_year: period.year, period_month: period.month)
  }

  scope :posted, -> {
    period = LastPostedPeriod.current
    where("period_year < :year OR (period_year = :year AND period_month < :month)", {year: period.year, month: period.month})
    .order(period_year: :desc, period_month: :desc)
  }

  def previous
    employee.payslips.
        where("period_year < :year OR (period_year = :year AND period_month < :month)", {year: period.year, month: period.month}).
        order(period_year: :desc, period_month: :desc).first
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

  def self.for_employee_for_period( employee, period)
    return nil if employee.nil?
    return nil if period.nil?
    result = employee.payslips.where("period_month = ? AND period_year = ?", period.month, period.year)
    if (result.size == 1)
      return result.first
    else
      return nil
    end
  end

  def self.most_recent(employee)
    employee.payslips.order(period_year: :desc, period_month: :desc).first
  end

  def self.process(employee, period=Period.current)
    return self.process_payslip(employee, period)
  end

  def self.process_all(employees, period)
    payslips = Array.new

    employees.each do |emp|
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

    wage = result * 0.72 # MAGIC!
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

  def prime_de_caisse
    earnings.where(is_caisse: true, is_bonus: true).where("description like '%Caisse%'").take
  end

  def salary_advance
    advance = deductions.advances.sum(:amount)
    advance.nil? ? 0 : advance
  end

  def salary_earnings
    # Need something better.
    earnings.where(overtime: false, is_bonus: false, is_caisse: false).where("description not like 'Misc. Pay%'")&.take&.amount
  end

  def first_page_deductions_sum
    total_tax.to_i
  end


  def period
    if (period_year && period_month)
      return Period.new(period_year, period_month)
    else
      return nil
    end
  end

  # See `compute_fullcnpswage`
  def full_base_pay
    base_pay(true)
  end

  def base_pay(full=false)
    # If we have a bonus base, we've already run
    # Don't return cached version if we're asking for full
    if (!full && self[:bonusbase])
      return self[:basepay]
    end

    days_in_month = employee.workdays_per_month(period)

    self[:days] = days_worked()
    self[:hours] = hours_worked()

    earning = Earning.new

    if (full || (worked_full_month? && employee.paid_monthly?))
      earning.description = "Monthly Wages"
      earning.amount = employee.wage
    elsif (employee.paid_monthly? && days > 0)
      earning.description = "Monthly wages for #{days} days @ #{employee.daily_rate}"
      earning.rate = employee.daily_rate
      earning.amount = daily_earnings
    elsif (!employee.paid_monthly? && hours_worked > 0)
      earning.description = "Hourly earnings for #{hours_worked} hours"
      earning.rate = employee.hourly_rate
      earning.amount = hourly_earnings
    end

    if (full || (!receives_no_pay? && earning.amount && earning.amount > 0))
      earnings << earning unless full
      self[:basepay] = earning.amount unless full
      earning.amount
    else
      self[:basepay] = 0
    end
  end

  def worked_full_month?
    WorkHour.worked_full_month(employee, period)
  end

  def days_worked
    receives_no_pay? ? 0 : WorkHour.days_worked(employee, period)
  end

  def days_not_worked
    employee.workdays_per_month(period) - self[:days]
  end

  def hours_worked
    receives_no_pay? ? 0 : WorkHour.hours_worked(employee, period)
  end

  def daily_earnings
    # Much debated, the daily earnings (partial month calculation) will
    # use the employee's daily rate times the days worked.
    daily_earnings = ( employee.daily_rate * self[:days] ).round

    # In the case that the employee doesn't works 22 days of a 23 day
    # month, he/she could make more than the monthly pay. This could
    # result in the employee earning more than their monthly amount.
    # In that case, just give them their monthly pay.
    if (daily_earnings > wage)
      wage
    else
      daily_earnings
    end
  end

  def hourly_earnings
    hours_worked = WorkHour.hours_worked(employee, period)

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

    vacation_worked = hours[:vacation_worked] || 0
    vacation_worked_earnings = vacation_worked * employee.hourly_rate
    vacation_earning = Earning.new(amount: vacation_worked_earnings,
        description: "Vacation Hours Worked", hours: vacation_worked,
          rate: employee.hourly_rate, overtime: true)
    earnings << vacation_earning if vacation_worked_earnings > 0

    self[:overtime_earnings] = ot1_earnings + ot2_earnings +
        ot3_earnings + vacation_worked_earnings
  end

  # See `compute_fullcnpswage`
  def full_bonusbase
    ( full_base_pay ).ceil
  end

  def compute_bonusbase
    self[:bonusbase] = ( base_pay + overtime_earnings ).ceil
  end

  # See `compute_fullcnpswage`
  def full_caissebase
    ( ( full_bonusbase ).ceil + seniority_bonus(true) ).ceil
  end

  def compute_caissebase
    self[:caissebase] = ( compute_bonusbase + seniority_bonus ).ceil
  end

  # Attempt to figure out, on the fly what the cnpswage will be
  # assuming full base pay. Also attempt to not cache values
  # that will be used again in the future
  # Does not include overtime or misc_pay to get "Standard Gross Wage"
  def compute_fullcnpswage
    ( full_caissebase + full_process_bonuses ).ceil
  end

  def compute_cnpswage
    self[:cnpswage] = ( compute_caissebase + process_bonuses + misc_pay ).ceil

    # NOTE: this previously used the Format(value, "0") VBA function, which I
    # intepreted as integer truncation.
    if (self[:cnpswage] > SystemVariable.value(:cnps_ceiling))
      self[:department_cnps] = ( self[:cnpswage] * SystemVariable.value(:dept_cnps_w_ceil) +
          SystemVariable.value(:dept_cnps_max_base) ).floor
    else
      self[:department_cnps] = ( self[:cnpswage] * SystemVariable.value(:dept_cnps) ).round
    end

    self[:department_severance] = ( employee.department_severance_rate(period) * self[:cnpswage] ).floor

    self[:cnpswage]
  end

  def process_taxable_wage
    transportation = employee.transportation ? employee.transportation : 0
    transportation = 0 if receives_no_pay?

    self[:taxable] = ( compute_cnpswage + transportation ).ceil

    # NOTE: this previously used the Format(value, "0") VBA function, which I
    # intepreted as integer truncation.
    self[:department_credit_foncier] = ( self[:taxable] *
        SystemVariable.value(:dept_credit_foncier) ).round

    if (self[:taxable] > SystemVariable.value(:emp_fund_salary_floor) && employee.employee_fund)
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
    self[:union_dues] = receives_no_pay? ? 0 : employee.union_dues_amount

    if (taxable == 0)
      self[:total_tax] = tax.total_tax
    else
      self[:total_tax] = tax.total_tax + union_dues
    end

  end

  # After all calculations, compute net pay from gross pay
  # less all deductions
  def compute_net_pay
    self[:raw_net_pay] = self[:gross_pay] - self[:total_tax] -
        total_deductions()

    Rails.logger.debug("[E: #{employee.id}] GP: #{gross_pay} - (TT: #{total_tax} + TD: #{total_deductions()}) = RNP: #{raw_net_pay}")

    if (self[:raw_net_pay] >= -4)
      if (employee.create_location_transfer?)
        # TODO Should this be added as a charge as well?
        deduction = Deduction.new
        deduction.note = "#{Payslip::LOCATION_TRANSFER} #{employee.location&.upcase}"
        deduction.deduction_type = Charge.charge_types["location_transfer"]
        deduction.amount = Payslip.cfa_round(self[:raw_net_pay])
        deduction.date = period.finish

        deductions << deduction

        self[:net_pay] = self[:raw_net_pay] = 0
      else
        self[:net_pay] = Payslip.cfa_round(self[:raw_net_pay])
      end
    else
      # This isn't good.  Give up.
      # This will raise an error since there's a model
      # validation that net_pay must be
      # greater_than_or_equal_to zero.
      self[:net_pay] = self[:raw_net_pay]
    end

    self[:salaire_net] = self[:taxable] - self[:total_tax]
  end


  def compute_work_loans
    work_loans_by_dept = WorkLoan.work_loan_hash(employee, period)
    percentage_so_far = 0

    if (work_loans_by_dept.size > 0)
      # NOTE: always compute based on hours worked. This would
      # distribute overtime between departments.
      hours_worked_this_month = employee.hours_day * self[:days]

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
    self[:transportation] = receives_no_pay? ? 0 : employee.transportation

    self[:category] = Employee.categories[employee.category]
    self[:echelon] = Employee.echelons[employee.echelon]
    self[:wagescale] = Employee.wage_scales[employee.wage_scale]

    self[:vac_accrue] = employee.accrues_vacation?

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

  def seniority_bonus(full=false)
    self[:years_of_service] = employee.years_of_service(period)
    self[:seniority_benefit] = SystemVariable.value(:seniority_benefit)

    if (full || (employee_eligible_for_seniority_bonus? && !receives_no_pay?))
      bonus = ( employee.find_base_wage() *
          ( self[:seniority_benefit] * self[:years_of_service] )).round
    else
      bonus = 0
      #self[:seniority_benefit] = 0
    end

    self[:seniority_bonus_amount] = bonus if !full

    bonus
  end

  def process_employee_deductions()
    return if receives_no_pay?

    expenses_hash = employee.deductable_expenses()

    expenses_hash.each do |k,v|
      amount = employee.send(v)

      if (amount && amount > 0)
        deduction = Deduction.new

        deduction.note = k
        deduction.amount = amount
        deduction.deduction_type = Charge.charge_types["other"]
        deduction.date = period.start

        deductions << deduction
      end
    end
  end

  def vacation_daily_rate
    #return 0 if (vacation_balance == 0)

    (( compute_fullcnpswage ) * Vacation::MONTHLY ).
        fdiv(SystemVariable.value(:vacation_pay_factor).to_f).
        fdiv(SystemVariable.value(:vacation_days).to_f)
  end

  def calc_vacation_pay_earned
    return 0 unless employee.accrues_vacation?
    # TODO/FIXME, incorporate supplemental pay?
    taxable.fdiv(SystemVariable.value(:vacation_pay_factor)).ceil
  end

  def receives_no_pay?
    on_vacation_entire_period? || employee.is_on_leave?
  end

  def on_vacation_entire_period?
    (Vacation.days_used(employee, period) >= employee.workdays_per_month(period)) ||
        WorkHour.only_worked_holidays?(employee, period)
  end

  private

  def self.process_payslip(employee, period)
    employee.save

    payslip = Payslip.find_by(
                  employee_id: employee.id,
                  period_year: period.year,
                  period_month: period.month)

    # If the employee shouldn't get a payslip this month,
    # and one exists, delete it.
    unless employee.is_currently_paid? || employee.is_on_leave?
      if payslip
        payslip.destroy
      end

      return nil
    end

    if (payslip.nil?)
      payslip = employee.payslips.build(period_year: period.year,
        period_month: period.month, payslip_date: Date.today)
    end

    begin

      payslip.reset_payslip
      payslip.store_employee_attributes

      self.process_earnings_and_taxes(payslip, employee, period)
      self.process_vacation(payslip, employee, period)

      self.process_charges_and_payments(payslip, employee)
      self.process_post_tax_bonuses(payslip, employee)
      payslip.process_employee_deductions()
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

  def full_process_bonuses
    process_bonuses(true)
  end

  def process_bonuses(full=false)
    # If we have a CNPS wage, we've already done this.
    # Don't return cached version if we're asking for full
    if (!full && self[:cnpswage])
      return self[:bonuspay]
    end

    if (!full && receives_no_pay?)
      return self[:bonuspay] = 0
    end

    bonus_total = 0

    # NB this is only pre tax bonuses, some bonuses
    # are processes post tax later on.
    employee.bonuses.pretax.each do |bonus|
      earning = Earning.new
      earning.description = bonus.name

      if bonus.is_percentage_bonus?
        earning.percentage = bonus.quantity
      end

      base = nil
      if (bonus.base_percentage?)
        if (bonus.use_caisse)
          base = employee.wage + seniority_bonus(full)
        else
          base = employee.wage
        end
        earning.amount = bonus.effective_bonus(base).floor
      else
        if (bonus.use_caisse)
          base = full ? full_caissebase : caissebase
        else
          base = full ? full_bonusbase : bonusbase
        end
        earning.amount = bonus.effective_bonus(base).round
      end

      earning.is_bonus = true
      earning.is_caisse = true if bonus.use_caisse
      earnings << earning unless full

      bonus_total += earning.amount
    end

    self[:bonuspay] = bonus_total
  end

  def misc_pay
    misc_pay_total = 0

    employee.misc_payments.for_period(period).where(before_tax: true).each do |misc_payment|
      misc_pay_total += misc_payment.amount
      earnings << Earning.new(amount: misc_payment.amount,
          description: "Misc. Payment: #{misc_payment.note}", is_bonus: false)
    end

    misc_pay_total
  end

  def employee_eligible_for_seniority_bonus?
    employee.years_of_service(period) >=
        SystemVariable.value(:seniority_waiting_years)
  end

  def self.process_earnings_and_taxes(payslip, employee, period)
    payslip.process_taxable_wage
    #payslip.process_vacation_pay
    payslip.process_taxes
  end

  def self.process_charges_and_payments(payslip, employee)
    employee.charges.for_period(payslip.period).each do |charge|
      deduction = Deduction.new

      deduction.note = charge.note
      deduction.amount = charge.amount
      deduction.deduction_type = Charge.charge_types[charge.charge_type]
      deduction.date = charge.date

      payslip.deductions << deduction
    end

    employee.misc_payments.for_period(payslip.period).where(before_tax: false).each do |pmnt|
      deduction = Deduction.new

      deduction.note = pmnt.note.blank? ? "Misc. Payment" : pmnt.note
      deduction.amount = pmnt.amount * -1
      deduction.deduction_type = Charge.charge_types["other"]
      deduction.date = pmnt.date

      payslip.deductions << deduction
    end
  end

  def self.process_post_tax_bonuses(payslip, employee)
    employee.bonuses.posttax.each do |bonus|
      negcharge = Deduction.new
      negcharge.note = bonus.name
      negcharge.date = payslip.period.finish

      # posttax bonuses always use gross as base
      base = payslip.gross_pay
      negcharge.amount = -1 * bonus.effective_bonus(base).round
      negcharge.deduction_type = Charge.charge_types["other"]

      payslip.deductions << negcharge
    end
  end

  def self.process_vacation(payslip, employee, period)
    # Supplemental days are added to each payslip as they happen. They are
    # no longer banked. Employees do not get extra days if they do not work
    # that month (just lke standard days). The vacation pay balance is the
    # pay that would receive if they took all their days at once (regular
    # and supplementary). Running totals of pay are no longer necessary.
    previous_payslip = payslip.previous

    compute_vacation_balances(previous_payslip, payslip)
    store_last_vacation(payslip)
  end

  def self.process_loans(payslip, employee, period)
    payments = LoanPayment.get_all_payments(employee, period)

    payments.each do |pmnt|
      next if pmnt.cash?

      deduction = Deduction.new

      deduction.note = LoanPayment::LOAN_PAYMENT_NOTE
      deduction.amount = pmnt.amount
      deduction.deduction_type = Charge.charge_types["other"]
      deduction.date = pmnt.date

      payslip.deductions << deduction
    end

    payslip.loan_balance = Loan.total_balance(employee, period)
  end

  def self.process_payslip_corrections(payslip, employee, period)
    corrections = employee.payslip_corrections.for_period(period)
    corrections.each do |correction|
      if correction.cfa_credit
        payslip.deductions << Deduction.new(amount: (correction.cfa_credit * -1), date: period.finish, deduction_type: Charge.charge_types["other"], note: "Correction, #{correction.payslip.period} : #{correction.note}")
      elsif correction.cfa_debit
        payslip.deductions << Deduction.new(amount: correction.cfa_debit, date: period.finish, deduction_type: Charge.charge_types["other"], note: "Correction, #{correction.payslip.period} : #{correction.note}")
      end

      # TODO, What to do with this?
      unless correction.vacation_days == 0
        payslip.vacation_balance += correction.vacation_days
      end
    end
  end

  def self.compute_vacation_balances(previous_payslip, payslip)
    payslip.vacation_pay_earned = payslip.calc_vacation_pay_earned

    # This is changed to just look at prior records instead of
    # anything else.
    if payslip.receives_no_pay?
      payslip.vacation_earned = 0
      payslip.period_suppl_days = 0
    else
      payslip.vacation_earned = Vacation.days_earned(payslip.employee, payslip.period)
      payslip.period_suppl_days = Vacation.period_supplemental_days(payslip.employee, payslip.period)
    end

    # previous
    # is Vacation.balance correct? XXX No!
    # look in most_recent payslip?
    prev_balance = previous_payslip.nil? ? Vacation.balance(payslip.employee, payslip.period.previous) : previous_payslip.vacation_balance || 0
    cur_balance = prev_balance + payslip.vacation_earned

    # FIXME set this to an initial value.
    payslip.vacation_balance = cur_balance
    payslip.vacation_pay_balance = 0

    # Update vacation used (substraction)
    update_vacation_balances(payslip, cur_balance)

    current_pay_balance(previous_payslip, payslip)
  end

  def self.store_last_vacation(payslip)
    last_vacation = payslip.employee.vacations.where('end_date <= ?', payslip.period.finish).last
    unless last_vacation.nil?
      payslip.last_vacation_start = last_vacation.start_date
      payslip.last_vacation_end = last_vacation.end_date
    end
  end

  def self.current_pay_balance(previous_payslip, payslip)
    # compute based on current balance
    payslip.vacation_pay_balance = ( payslip.vacation_daily_rate * payslip.vacation_balance ).round
  end

  def self.update_vacation_balances(payslip, cur_balance)
    vacation_days_used = 0
    if (cur_balance == 0)
      vacation_pay_used = 0
    else
      vacation_pay_used = 0

      payslip.vacation_balance = cur_balance

      # Vacations are applied to the period which has the most days
      # if the vacation spans more than one period.
      vacations = Vacation.for_period_for_employee(payslip.employee, payslip.period)
      vacations.each do |vac_in_period|
        if (vac_in_period.apply_to_period() == payslip.period)
          #Rails.logger.error("Working on vac for #{vac_in_period.start_date} to #{vac_in_period.end_date} which is #{vac_in_period.days}")
          if (cur_balance == 0)
            vacation_pay_used += 0
          else
            vacation_days_used += vac_in_period.days
            vacation_pay_used += vac_in_period.vacation_pay(payslip)
          end
        end
      end
    end

    if ((cur_balance.round(2) - vacation_days_used) < 0)
      Rails.logger.error("CB: #{cur_balance} less #{vacation_days_used} for period #{payslip.period}")
      raise Exception.new("Insufficient vacation balance to take this month's vacation, Please Correct.")
    end

    payslip.vacation_used = vacation_days_used
#    Rails.logger.error("Setting VPU to #{vacation_pay_used} //")
    payslip.vacation_pay_used = vacation_pay_used
    payslip.vacation_balance = cur_balance - vacation_days_used
  end

  # Round to the next 5
  def self.cfa_round(input)
    ((input + 4) / 5).to_i * 5
  end

end
