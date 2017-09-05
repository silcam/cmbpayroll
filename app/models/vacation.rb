include ApplicationHelper

class Vacation < ApplicationRecord

  belongs_to :employee

  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start
  validate :doesnt_overlap_existing

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
    # TODO Revisit this rule
    end_date > Period.current.start
  end

  def self.period_vacations(period = Period.current)
    Vacation.where(overlap_clause(period.start, period.finish))
  end

  def self.upcoming_vacations
    Vacation.all.where("start_date > ?", Period.current.finish)
  end

  def self.missed_days(employee, period=Period.current)
    missed_days_for employee, period.start, period.finish
  end

  def self.missed_hours(employee, period=Period.current)
    missed_days(employee, period) * WorkHour.workday
  end

  def self.missed_days_so_far(employee)
    missed_days_for employee, Period.current.start, yesterday
  end

  def self.missed_hours_so_far(employee)
    Vacation.missed_days_so_far(employee) * WorkHour.workday
  end

  def self.vacation_days(work_hours)
    employee = work_hours.first.employee
    vacations = employee.vacations.where(overlap_clause(work_hours.first.date, work_hours.last.date))
    vdays = work_hours.collect do |work_hour|
      vacations.any?{ |vacay| (vacay.start_date .. vacay.end_date) === work_hour.date }
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

  def self.missed_days_for(employee, start_date, end_date)
    vacations = employee
                    .vacations
                    .where(overlap_clause(start_date, end_date))
    missed = 0
    vacations.each do |vacation|
      (vacation.start_date .. vacation.end_date).each do |day|
        if( is_weekday?(day) and
            (start_date .. end_date) === day )
          missed += 1
        end
      end
    end
    missed
  end

  def self.overlap_clause(start_date, end_date)
    ["(start_date BETWEEN :start AND :end) OR
      (end_date BETWEEN :start AND :end) OR
      (start_date < :start AND end_date > :end)",
     {start: start_date, end: end_date}]
  end
end
