include ApplicationHelper

class Vacation < ApplicationRecord

  MONTHLY = 12.0

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

  def self.upcoming_vacations
    Vacation.all.where("start_date > ?", Period.current.finish)
  end

  def self.days_earned(employee, period)
    return 0 if period.finish < employee.first_day
    earned = SystemVariable.value(:vacation_days) / 12.0
    earned + supplemental_days(employee, period)
  end

  def self.supplemental_days(employee, period)
    if period.month == employee.contract_start.try(:month)
      years = period.year - employee.contract_start.year
      multiple = years / SystemVariable.value(:supplemental_days_period) # Integer division intentional
      earned = multiple * SystemVariable.value(:supplemental_days)
      earned + mom_supplemental_days(employee)
    else
      0
    end
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

  def self.pay_earned(employee, period)
    period_days = days_used(employee, period)
    pay_earned_with_days(employee, period, period_days)
  end

  def self.pay_earned_with_days(employee, period, days)
    pay = Payslip.find_pay(employee)
    vacation_pay = (Vacation.vacation_daily_rate(pay) * days).ceil
  end

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

  def prep_print
    vacation_pay
    self[:paid] = true
  end

  # Compute vacation pay for this vacation based on who took
  # it and how long it is.
  def vacation_pay
    if (self[:vacation_pay].nil?)
      pay = Payslip.find_pay(employee)
      vacation_pay = (Vacation.vacation_daily_rate(pay) * days).ceil
      self[:vacation_pay] = vacation_pay
    end

    self[:vacation_pay]
  end

  def get_tax
    if @tax.nil?
      @tax = Tax.compute_taxes(employee, vacation_pay, vacation_pay)
    else
      @tax
    end
  end

  # def self.missed_days(employee, period=Period.current)
  #   missed_days_for employee, period.start, period.finish
  # end
  #
  # def self.missed_hours(employee, period=Period.current)
  #   missed_days(employee, period) * WorkHour.workday
  # end

  # def self.missed_days_so_far(employee)
  #   missed_days_for employee, Period.current.start, yesterday
  # end
  #
  # def self.missed_hours_so_far(employee)
  #   Vacation.missed_days_so_far(employee) * WorkHour.workday
  # end

  # def prev_vacation_pay_balance
  #   previous_slip = previous
  #   previous_slip.nil? ? 0 : previous_slip.vacation_pay_balance
  # end

  # def calculate_vacation_pay_used
  #   days_used = Vacation.days_used employee, period
  #   previous_days_balance = Vacation.balance(employee, period.previous)
  #   previous_pay_balance = prev_vacation_pay_balance
  #   ((previous_pay_balance * days_used) / previous_days_balance).to_i
  # end

  # def calculate_vacation_pay_balance
  #   prev_vacation_pay_balance +
  #     calculate_vacation_pay -
  #     calculate_vacation_pay_used
  # end

  # def calculate_vacation_pay(cnpswage, vacation_used)
  #   (vacation_daily_rate(cnpswage) * vacation_used).ceil
  # end

  def self.vacation_daily_rate(cnpswage)
    days_earned = SystemVariable.value(:vacation_days) / MONTHLY
    vpay_factor = SystemVariable.value(:vacation_pay_factor)
    per_day = (cnpswage / days_earned) / vpay_factor
  end

  def get_vacation_pay
    vac_pay = earnings.where(description: VACATION_PAY)&.take
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

  private

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

  # def self.missed_days_for(employee, start_date, end_date)
  #   vacations = employee
  #                   .vacations
  #                   .where(overlap_clause(start_date, end_date))
  #   missed = 0
  #   vacations.each do |vacation|
  #     (vacation.start_date .. vacation.end_date).each do |day|
  #       if( is_weekday?(day) and
  #           (start_date .. end_date) === day )
  #         missed += 1
  #       end
  #     end
  #   end
  #   missed
  # end

  def self.overlap_clause(start_date, end_date)
    ["(start_date BETWEEN :start AND :end) OR
      (end_date BETWEEN :start AND :end) OR
      (start_date < :start AND end_date > :end)",
     {start: start_date, end: end_date}]
  end
end
