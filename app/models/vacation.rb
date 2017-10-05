include ApplicationHelper

class Vacation < ApplicationRecord

  belongs_to :employee

  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start
  validate :doesnt_overlap_existing
  validate :dont_violate_posted_period

  default_scope { order(:start_date) }

  after_save :remove_overlapped_work_hours

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
    not LastPostedPeriod.in_posted_period? start_date
  end

  def editable?
    not LastPostedPeriod.in_posted_period? end_date
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
    if period.month == employee.contract_start.try(:month)
      years = period.year - employee.contract_start.year
      multiple = years / SystemVariable.value(:supplemental_days_period) # Integer division intentional
      earned += multiple * SystemVariable.value(:supplemental_days)
    end
    earned
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

  def self.days_hash(employee, start, finish)
    vacations = employee.vacations.where(overlap_clause(start, finish))
    vdays = {}
    (start .. finish).each do |date|
      vdays[date] = {vacation: true} if vacations.any?{ |vacay| (vacay.start_date .. vacay.end_date) === date }
    end
    vdays
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
