include ApplicationHelper

class WorkHour < ApplicationRecord

  belongs_to :employee

  validates :date, presence: true
  validates :hours, numericality: true
  validate :not_during_vacation

  default_scope { order(:date) }
  scope :current_period, -> { where(date: (current_period_start .. current_period_end))}


  def self.total_hours(employee)
    #TODO Hardcoded value alert:
    normal = current_period_weekdays_so_far * 8
    overtime = 0
    work_hours = WorkHour.where(employee: employee,
                                date: (current_period_start .. Date.today-1))
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

  private

  def not_during_vacation
    unless employee and employee.vacations.
        where("start_date <= :date AND end_date >= :date", {date: date}).
        empty?
      errors.add(:date, I18n.t(:not_during_vacation))
    end
  end
end
