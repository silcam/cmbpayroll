include ApplicationHelper

class WorkHour < ApplicationRecord

  NUMBER_OF_HOURS_IN_A_WORKDAY = 8 # TODO make var
  NUMBER_OF_HOURS_IN_A_WEEKEND_WORKDAY = 0 # TODO make var

  belongs_to :employee

  validates :date, presence: true
  validates :hours, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 24}
  validate :not_during_vacation
  validate :not_during_posted_period

  default_scope { order(:date) }
  scope :current_period, -> { where(date: Period.current_as_range)}

  def self.for(employee, start, finish)
    where(employee: employee, date: (start .. finish))
  end

  def self.total_hours(employee, period=Period.current)
    total_hours_for employee, period.start, period.finish
  end

  def self.total_hours_so_far(employee)
    total_hours_for employee, Period.current.start, yesterday
  end

  def self.days_hash_for_week(employee, date)
    monday = last_monday date
    complete_days_hash employee, monday, (monday + 6)
  end

  def self.days_hash(employee, start, finish)
    work_hours = WorkHour.for(employee, start, finish)
    days = {}
    work_hours.each do |work_hour|
      days[work_hour.date] = {hours: work_hour.hours}
    end
    days
  end

  def self.complete_days_hash(employee, start, finish)
    days = RecursiveHashMerger.merge days_hash(employee, start, finish),
                                Holiday.days_hash(start, finish),
                                Vacation.days_hash(employee, start, finish)
    (start .. finish).each do |day|
      days[day] = {} unless days.has_key? day
    end
    days
  end

  def self.update(employee, days_hours)
    all_errors = []
    days_hours.each do |day, hours|
      day = Date.strptime day
      work_hour = employee.work_hours.find_or_initialize_by(date: day)
      work_hour.update(hours: hours)
      all_errors << work_hour.errors if work_hour.errors.any?
    end
    return all_errors.empty?, all_errors
  end

  def self.default_hours(date, holiday)
    is_off_day?(date, holiday) ? NUMBER_OF_HOURS_IN_A_WEEKEND_WORKDAY : WorkHour.workday
  end

  def self.default_hours?(date, holiday, hours)
    hours.to_d == default_hours(date, holiday)
  end

  def self.calculate_overtime(date, day_hash)
    return {} if day_hash[:hours].nil? or day_hash[:hours] == 0
    return {holiday: day_hash[:hours]} if holiday_overtime? date, day_hash
    if day_hash[:hours] > workday
      {normal: workday, overtime: (day_hash[:hours]-workday)}
    else
      {normal: day_hash[:hours]}
    end
  end

  def self.holiday_overtime?(date, day_hash)
    date.sunday? or day_hash.has_key? :holiday
  end

  def self.workday
    NUMBER_OF_HOURS_IN_A_WORKDAY
  end

  # Developer helper method. Call from the Rails console to populate some WorkHours
  # Comment out this line before running: validate :not_during_posted_period
  def self.fill_in_workhours(end_date)
    holidays = Holiday.days_hash(Date.new(2016, 1, 1), end_date)
    Employee.all.each do |emp|
      (emp.first_day .. end_date).each do |d|
        if emp.work_hours.find_by(date: d).nil?
          hours = is_off_day?(d, holidays[d]) ? 0 : 8
          emp.work_hours << WorkHour.new(date: d, hours: hours)
        end
      end
    end
  end

  private

  def not_during_vacation
    unless employee and employee.vacations.
        where("start_date <= :date AND end_date >= :date", {date: date}).
        empty?
      errors.add(:date, I18n.t(:not_during_vacation))
    end
  end

  def not_during_posted_period
    if date and date <= LastPostedPeriod.get.finish
      errors.add(:date, I18n.t(:cant_change_during_posted_period))
    end
  end

  def self.total_hours_for(employee, start, finish)
    hours = {}
    days = complete_days_hash(employee, start, finish)
    days.each do |date, day|
      unless day[:vacation]
        hours.merge! calculate_overtime(date, day) do |key, oldval, newval|
          oldval + newval
        end
      end
    end
    hours
  end
end

class InvalidHoursException < Exception
  def initialize(errors)
    @errors = errors
  end

  def errors
    @errors
  end
end
