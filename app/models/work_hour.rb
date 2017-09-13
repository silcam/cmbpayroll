include ApplicationHelper

class WorkHour < ApplicationRecord

  belongs_to :employee

  validates :date, presence: true
  validates :hours, numericality: true
  validate :not_during_vacation

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

  def self.week_for(employee, date)
    monday = last_monday date
    sunday = monday + 6
    existing = employee.work_hours.where(date: (monday .. sunday))
    week = []
    (monday .. sunday).each do |d|
      existing_i = existing.index{ |wh| wh.date == d }
      workhour = existing_i.nil? ?
                     WorkHour.new(employee: employee,
                                  date: d,
                                  hours: WorkHour.default_hours(d))
                     : existing[existing_i]
      week << workhour
    end
    week
  end

  def self.update(employee, days_hours)
    validate_hours!(days_hours)
    days_hours.each do |day, hours|
      day = Date.strptime day
      work_hour = employee.work_hours.find_by(date: day)
      if work_hour.nil?
        employee.work_hours.create(date: day, hours: hours) unless default_hours?(day, hours)
      else
        if default_hours?(day, hours)
          work_hour.destroy
        else
          work_hour.update(hours: hours)
        end
      end
    end
  end

  def self.validate_hours!(days_hours)
    errors = []
    days_hours.each do |day, hours|
      begin
        raise "Out of Range" unless (0..24) === hours.to_d
      rescue
        errors << "#{hours} #{I18n.t(:invalid_hours)}"
      end
    end
    raise InvalidHoursException.new(errors) unless errors.empty?
  end

  def self.default_hours(date)
    is_weekday?(date) ? WorkHour.workday : 0  #TODO hardcoded 0 hrs for weekend
  end

  def self.default_hours?(date, hours)
    hours.to_d == default_hours(date)
  end

  def self.workday
    8 #TODO hardcoded constant 1 wkday = 8 hrs
  end

  private

  def not_during_vacation
    unless employee and employee.vacations.
        where("start_date <= :date AND end_date >= :date", {date: date}).
        empty?
      errors.add(:date, I18n.t(:not_during_vacation))
    end
  end

  def self.total_hours_for(employee, start_date, end_date)
    normal = 0
    overtime = 0
    work_hours = WorkHour.for(employee, start_date, end_date)
    vacations = Vacation.vacation_days(employee, start_date, end_date)
    holidays = Holiday.hash_for(start_date, end_date)

    (start_date .. end_date).each do |date|
      next if vacations.include? date
      i = work_hours.index{ |wh| wh.date == date }
      work_hour = i.nil? ? nil : work_hours[i]
      if holidays[date] or not is_weekday?(date)
        overtime += work_hour.hours unless work_hour.nil?
      else
        if work_hour.nil?
          normal += workday
        else
          normal += [workday, work_hour.hours].min
          overtime += [0, work_hour.hours - workday].max
        end
      end
    end
    {normal: normal, overtime: overtime}
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
