include ApplicationHelper

class WorkHour < ApplicationRecord

  belongs_to :employee

  validates :date, presence: true
  validates :hours, numericality: true
  validate :not_during_vacation

  default_scope { order(:date) }
  scope :current_period, -> { where(date: Period.current_as_range)}

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

  def self.default_hours(date)
    is_weekday?(date) ? WorkHour.workday : 0  #TODO hardcoded 0 hrs for weekend
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
    normal = Period.weekdays_so_far * WorkHour.workday
    overtime = 0
    work_hours = WorkHour.where(employee: employee,
                                date: (start_date .. end_date))
    work_hours.each do |work_hour|
      if is_weekday? work_hour.date
        if work_hour.hours < 8
          normal += (work_hour.hours - 8)
        else
          overtime += (work_hour.hours - 8)
        end
      else
        overtime += work_hour.hours
      end
    end
    {normal: normal, overtime: overtime}
  end
end
