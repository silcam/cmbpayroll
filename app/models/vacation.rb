include ApplicationHelper

class Vacation < ApplicationRecord

  MONTHLY = 12.0
  YEAR = 365

  attr :tax

  belongs_to :employee

  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start
  validate :doesnt_overlap_existing
  validate :dont_violate_posted_period
  validate :cant_modify_if_already_paid

  default_scope { order(:start_date) }

  def save(*args)
    if super(*args)
      remove_overlapped_work_hours
      true
    else
      false
    end
  end

  def save!(*args)
    if super(*args)
      remove_overlapped_work_hours
      true
    else
      false
    end
  end

  def days
    number_of_days(start_date, end_date)
  end

  # NB. If two period have the same number of vacation
  # days, the earlier month will be returned.
  def apply_to_period
    start_period = Period.from_date(start_date)
    end_period = Period.from_date(end_date)

    if (start_period == end_period)
      return start_period
    end

    tmp_period = start_period
    period_with_most_days = tmp_period
    most_days = 0

    while (tmp_period <= end_period)
      tmp_period_days = days_in_period(tmp_period)

      if (tmp_period_days > most_days)
        most_days = tmp_period_days
        period_with_most_days = tmp_period
      end

      tmp_period = tmp_period.next
    end

    period_with_most_days
  end

  # NOTE: This only figures days used in period
  # for *this* vacation, not all vacations in
  # the period
  def days_in_period(period)
    return 0 if (end_date < period.start)
    return 0 if (start_date > period.finish)

    tmp_start_date = period.start
    tmp_end_date = period.finish

    # We overlap in some way, figure out which
    if (start_date > period.start)
      tmp_start_date = start_date
    end

    if (end_date < period.finish)
      tmp_end_date = end_date
    end

    number_of_days(tmp_start_date, tmp_end_date)
  end

  def overlaps_work_hours?
    not overlapped_work_hours(false).empty?
  end

  def overlapped_work_hours(include_zeros=true)
    return [] unless valid?
    where = 'date BETWEEN ? AND ?'
    where += ' AND hours > 0' unless include_zeros
    employee.work_hours.where(where, start_date, end_date)
  end

  def destroy
    if destroyable?
      super
    else
      false
    end
  end

  def destroyable?
    (not LastPostedPeriod.in_posted_period? start_date) && (not self[:paid])
  end

  def editable?
    (not LastPostedPeriod.in_posted_period? end_date) && (not self[:paid])
  end

  def self.for_period(period = Period.current)
    Vacation.where(overlap_clause(period.start, period.finish))
  end

  def self.starts_in(employee, period = Period.current)
    Vacation.where("employee_id = ?", employee&.id).
        where("start_date BETWEEN ? AND ?", period.start, period.finish)
  end

  def self.for_period_for_employee(employee, period = Period.current)
    Vacation.where(overlap_clause(period.start, period.finish)).where("employee_id = ?", employee.id)
  end

  def self.upcoming_vacations
    Vacation.all.where("start_date > ?", Period.current.finish)
  end

  # FIXME : Verify algorithm.
  def self.days_earned(employee, period)
    return 0 if period.finish < employee.first_day
    return 0 unless employee.accrues_vacation?
    earned = SystemVariable.value(:vacation_days).fdiv(MONTHLY)
    earned + period_supplemental_days(employee, period)
  end

  def self.period_supplemental_days(employee, period)
    return 0 unless employee.accrues_vacation?

    mom_days = mom_supplemental_days(employee)

    years_diff = (period.finish.year - Period.from_date(employee.contract_start).finish.year)
    years = (years_diff).div(SystemVariable.value(:supplemental_days_period))
    days = (years * SystemVariable.value(:supplemental_days).fdiv(MONTHLY.to_f) + mom_days)

    days = 0 if (days < 0)

    days
  end

  def self.first_supplemental_accrual_period(employee)
    # The period after the 4th anniversary
    anniv = (employee.contract_start.to_datetime >> (
        (SystemVariable.value(:supplemental_days_period) - 1) * MONTHLY
    )).next_month
    Period.new(anniv.year, anniv.month)
  end

  def self.mom_supplemental_days(employee)
    if employee.female?
      2 * employee.children_under_6
    else
      0
    end
  end

  def self.days_used(employee, period)
    days = RecursiveHashMerger.merge Vacation.days_hash(employee, period.start, period.finish),
                                     Holiday.days_hash(period.start, period.finish)
    used = 0
    days.each do |date, day|
      if day[:vacation] and not is_off_day?(date, day[:holiday])
        used += 1
      end
    end
    used
  end

  # FIXME: move?
  # If the period is posted, look in the payslip.
  # Otherwise, guess -- since things are going
  # change anyways.
  def self.balance(employee, period)
    if LastPostedPeriod.posted? period
      payslip = employee.payslip_for period
      return payslip.nil? ? 0 : payslip.vacation_balance
    else
      payslip = employee.payslip_for LastPostedPeriod.get
      start_period = payslip.nil? ? Period.from_date(employee.first_day).previous
                         : LastPostedPeriod.get
      balance = payslip.nil? ? 0 : payslip.vacation_balance
      (start_period.next .. period).each do |p|
        balance = balance + days_earned(employee, p) - days_used(employee, p)
      end
    end
    balance
  end

  def self.on_vacation_during(employee, start, finish)
    check_date = start
    while check_date <= finish
      vacation = employee.vacations.find_by("start_date <= :date AND end_date >= :date", date: check_date)
      return false unless vacation
      check_date = vacation.end_date + 1
    end
    return true
  end

  def self.days_hash(employee, start, finish)
    vacations = employee.vacations.where(overlap_clause(start, finish))
    vdays = {}
    (start .. finish).each do |date|
      vdays[date] = {vacation: true} if vacations.any?{ |vacay| (vacay.start_date .. vacay.end_date) === date }
    end
    vdays
  end

  # Only the payslip knows
  def self.vacation_daily_rate(employee)
    # Previous algorithm just used cnps wage as parameter
    # then figured out how much vacation pay is for that
    # (1/16th), per day.

    # This will look at the most recent payslip for this user.
    # and determine a few things from there.
    payslip = Payslip.most_recent(employee)
    payslip.vacation_daily_rate
  end

  def prep_print
    vacation_pay
  end

  def mark_paid
    prep_print
    self[:paid] = true
  end

  # Compute vacation pay for this vacation based on balances
  # in employee's payslip.
  def vacation_pay(payslip=nil)
    period = Period.from_date(start_date)

    applied_period = apply_to_period
    self[:period_month] = applied_period.month
    self[:period_year] = applied_period.year

    # if not passed in, attempt to find payslip
    if (payslip.nil?)
      payslip = Payslip.most_recent(employee)
    end

    return 0 if payslip.nil?
    return 0 if payslip.vacation_pay_balance.nil?
    return 0 if payslip.vacation_balance == 0

    # FIXME similar to payslip line 794
    self[:vacation_pay] = ( payslip.vacation_daily_rate * days ).round

    # This may need some cleanup
    tax = Tax.compute_taxes(employee, self[:vacation_pay], self[:vacation_pay])
    self[:ccf] = tax.ccf
    self[:crtv] = tax.crtv
    self[:proportional] = tax.proportional
    self[:cac] = tax.cac
    self[:cac2] = tax.cac2
    self[:communal] = tax.communal
    self[:cnps] = tax.cnps
    self[:total_tax] = tax.total_tax

    self[:vacation_pay]
  end

  def net_pay
    vacation_pay - (get_tax().total_tax())
  end

  def pay_per_period(period)
    ps = employee.payslip_for(Period.from_date(start_date))

    if (ps.nil? || ps.vacation_balance == 0)
      0
    else
      period_days = days_in_period(period)
      (ps.vacation_daily_rate * period_days).round
    end
  end

  def get_tax
    if @tax.nil?
      vac_pay = vacation_pay()
      @tax = Tax.compute_taxes(employee, vac_pay, vac_pay)
    else
      @tax
    end
  end

  private

  def number_of_days(start_date, end_date)
    tmp_start_date = start_date.clone
    holidays = Holiday.days_hash(start_date, end_date)

    count = 0
    while (tmp_start_date <= end_date)
      unless (is_off_day?(tmp_start_date) || holidays.has_key?(tmp_start_date))
        count += 1
      end
      tmp_start_date += 1
    end

    count
  end

  def end_date_after_start
    return if end_date.blank? or start_date.blank?
    errors.add(:end_date, I18n.t(:after_start_date)) if end_date < start_date
  end

  def doesnt_overlap_existing
    return if employee.nil? or start_date.blank? or end_date.blank?
    existing = employee.vacations
    existing = existing.where('id != ?', id) if id
    unless existing.where(overlap_clause).empty?
      errors.add(:base, I18n.t(:Vacation_overlaps))
    end
  end

  def remove_overlapped_work_hours
    overlapped_work_hours.each{ |wh| wh.destroy! }
  end

  def overlap_clause
    Vacation.overlap_clause(start_date, end_date)
  end

  def dont_violate_posted_period
    if new_record?
      if LastPostedPeriod.in_posted_period? start_date
        errors.add :start_date, I18n.t(:cant_be_during_posted_period)
      end
    else
      if start_date_changed? and LastPostedPeriod.in_posted_period? start_date, start_date_was
        errors.add :start_date, I18n.t(:cant_change_during_posted_period)
      end
      if end_date_changed? and LastPostedPeriod.in_posted_period? end_date, end_date_was
        errors.add :end_date, I18n.t(:cant_change_during_posted_period)
      end
    end
  end

  def cant_modify_if_already_paid
    if (self[:paid])
      if start_date_changed?
        errors.add :start_date, I18n.t(:cant_change_paid_record)
      end
      if end_date_changed?
        errors.add :end_date, I18n.t(:cant_change_paid_record)
      end
    end
  end

  def self.overlap_clause(start_date, end_date)
    ["(start_date BETWEEN :start AND :end) OR
      (end_date BETWEEN :start AND :end) OR
      (start_date < :start AND end_date > :end)",
     {start: start_date, end: end_date}]
  end
end
