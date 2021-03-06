include ApplicationHelper

class WorkHour < ApplicationRecord

  NUMBER_OF_HOURS_IN_A_WORKDAY = 8
  NUMBER_OF_HOURS_IN_A_WEEKEND_WORKDAY = 0

  belongs_to :employee

  validates :date, presence: true
  validates :hours, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 24}
  validates :excused_hours, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 24, allow_blank: true}
  validates :vacation_worked, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 24, allow_blank: true}
  validate :hours_not_during_vacation
  validate :vacation_worked_during_vacation
  validate :not_during_posted_period

  default_scope { order(:date) }
  scope :current_period, -> { where(date: Period.current_as_range)}

  def update_with_params(params)
    self.hours = params[:hours].to_f
    self.excused_hours = params[:excused_hours].to_f if params[:excused_hours]
    self.vacation_worked = params[:vacation_worked].to_f if params[:vacation_worked]
    self.excuse = params[:excuse]
    save
  end

  def self.for(employee, start, finish)
    where(employee: employee, date: (start .. finish))
  end

  def self.total_hours(employee, period=Period.current)
    total_hours_for employee, period.start, period.finish
  end

  def self.days_hash_for_week(employee, date)
    monday = last_monday date
    complete_days_hash employee, monday, (monday + 6)
  end

  def self.days_hash(employee, start, finish)
    work_hours = WorkHour.for(employee, start, finish)
    days = {}
    work_hours.each do |work_hour|
      days[work_hour.date] = {hours: work_hour.hours,
                              vacation_worked: work_hour.vacation_worked,
                              excused_hours: work_hour.excused_hours,
                              excuse: work_hour.excuse }
    end
    days
  end

  def self.days_worked(employee, period)
    hours_worked, days_worked, holiday_days, vac_days_worked = self.compute_hours_and_days(employee, period)
    days_worked
  end

  def self.hours_worked(employee, period)
    hours_worked, days_worked, holiday_days, vac_days_worked = self.compute_hours_and_days(employee, period)
    hours_worked
  end

  def self.holiday_days_in_period(employee, period)
    hours_worked, days_worked, holiday_days, vac_days_worked = self.compute_hours_and_days(employee, period)
    holiday_days
  end

  def self.vac_days_worked_in_period(employee, period)
    hours_worked, days_worked, holiday_days, vac_days_worked = self.compute_hours_and_days(employee, period)
    vac_days_worked
  end

  def self.worked_full_month(employee, period)
    if (employee.paid_monthly?)
      # days possible vs days worked.
      days_worked = WorkHour.days_worked(employee, period)
      days_per_month = employee.workdays_per_month(period)

      days_worked >= days_per_month
    else
      # hours possible vs hours worked.
      hours_worked = WorkHour.hours_worked(employee, period)
      hours_per_month = employee.hours_per_month()

      hours_worked >= hours_per_month
    end
  end

  # FIXME, these might not be the same exact days?
  # but the holidays would also appear in the days
  # worked ??
  def self.only_worked_holidays?(employee, period)
    return (holiday_days_in_period(employee, period) ==
        ( days_worked(employee, period) +
          vac_days_worked_in_period(employee, period) ) )
  end

  def self.complete_days_hash(employee, start, finish)
    days = RecursiveHashMerger.merge days_hash(employee, start, finish),
                                Holiday.days_hash(start, finish),
                                Vacation.days_hash(employee, start, finish)
    (start .. finish).each do |day|
      # Ensure that every day has a hash with at least hours and excused_hours defined
      hours_not_entered = days[day].nil? || days[day][:hours].nil?
      days[day] = {hours: 0, vacation_worked: 0, excused_hours: 0}.merge(days[day] || {})
      days[day][:hours_not_entered] = hours_not_entered
    end
    days
  end

  def self.update(employee, days_hours)
    all_errors = []
    days_hours.each do |day, hours_hash|
      day = Date.strptime day
      work_hour = employee.work_hours.find_or_initialize_by(date: day)
      work_hour.update_with_params hours_hash
      all_errors << work_hour.errors if work_hour.errors.any?
    end
    return all_errors.empty?, all_errors
  end

  def self.employees_lacking_work_hours(period)
    employees = Employee.where("employees.id NOT IN
                    (SELECT DISTINCT employee_id FROM work_hours
                    WHERE work_hours.date BETWEEN :start AND :finish)",
                   {start: period.start, finish: period.finish}).currently_paid()
    return employees.reject{ |e| Vacation.on_vacation_during(e, period.start, period.finish)}
  end

  def self.default_hours(date, holiday)
    is_off_day?(date, holiday) ? NUMBER_OF_HOURS_IN_A_WEEKEND_WORKDAY : WorkHour.workday
  end

  def self.default_hours?(date, holiday, hours)
    hours.to_d == default_hours(date, holiday)
  end

  def self.calculate_overtime(date, day_hash)
    # handle as regular hours
    if day_hash[:vacation_worked] && day_hash[:vacation_worked] > 0
      day_hash[:hours] = day_hash[:vacation_worked]
      day_hash[:vacation_worked] = 0
    end

    return {} if day_hash[:hours].nil? or day_hash[:hours] == 0

    if (day_hash.has_key? :holiday)
      {holiday: day_hash[:hours]}
    elsif day_hash[:vacation] == true
      {vacation_worked: day_hash[:hours]}
    else
      if holiday_overtime?(date, day_hash)
        {holiday: day_hash[:hours]}
      elsif is_off_day? date
        {overtime: day_hash[:hours]}
      elsif day_hash[:hours] > workday
        {normal: workday, overtime: (day_hash[:hours]-workday)}
      else
        {normal: day_hash[:hours]}
      end
    end
  end

  def self.holiday_overtime?(date, day_hash)
    date.sunday? or day_hash.has_key? :holiday
  end

  def self.workday
    NUMBER_OF_HOURS_IN_A_WORKDAY
  end


  # Differs from below method in that it can only be used for one employee, and
  # for only the current open period, not any arbitrary end date
  def self.fill_default_hours(employee, period)
    fill_hours(employee, period.start, period.finish)
  end

  # Developer helper method. Call from the Rails console to populate some WorkHours
  # Comment out this line before running: validate :not_during_posted_period
  def self.fill_in_workhours(end_date)
    Employee.all.each do |emp|
      fill_hours(emp, emp.first_day, end_date, holidays)
    end
  end

  private

  def self.fill_hours(employee, start_date, end_date)
    holidays = Holiday.days_hash(start_date, end_date)
    (start_date .. end_date).each do |d|
      if employee.work_hours.find_by(date: d).nil?
        hours = is_off_day?(d, holidays[d]) ? 0 : 8
        employee.work_hours << WorkHour.new(date: d, hours: hours)
      end
    end
  end

  def hours_not_during_vacation
    if (employee and !employee.vacations.
        where("start_date <= :date AND end_date >= :date", {date: date}).
        empty?) && (hours > 0 || excused_hours > 0)
      errors.add(:date, I18n.t(:not_during_vacation))
    end
  end

  def vacation_worked_during_vacation
    if (employee and employee.vacations.
        where("start_date <= :date AND end_date >= :date", {date: date}).
        empty?) && vacation_worked > 0
      errors.add(:date, I18n.t(:must_be_during_vacation))
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
      hours.merge! calculate_overtime(date, day) do |key, oldval, newval|
        oldval + newval
      end
    end

    hours
  end

  # TODO: Right now this just looks per day checks that at least
  # 8 hours were worked.  An alternative algorithm would look
  # at a 40 hours week or some other equivalent.  I'm not sure which
  # is better.
  def self.compute_hours_and_days(employee, period)
    days_worked = 0
    hours_worked = 0
    holiday_days = 0
    vac_days_worked = 0

    days = WorkHour.complete_days_hash(employee, period.start, period.finish)

    date = period.start
    while date <= period.finish
      if days[date]
        if days[date][:holiday] && is_weekday?(date)
          holiday_days += 1
          days_worked += 1
          hours_worked += NUMBER_OF_HOURS_IN_A_WORKDAY
        elsif days[date][:hours] > 0 or days[date][:excused_hours] > 0
          hours_worked_that_day = days[date][:hours] + days[date][:excused_hours]
          hours_worked += hours_worked_that_day

          if !is_off_day?(date, days[date][:holiday]) && hours_worked_that_day.to_i >= WorkHour.workday
            days_worked += 1
          end
        elsif days[date][:vacation] && days[date][:vacation_worked] > 0
          vac_days_worked += 1
        end
      end

      date += 1
    end

    return hours_worked, days_worked, holiday_days, vac_days_worked
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
