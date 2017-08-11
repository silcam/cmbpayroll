include ApplicationHelper

class Vacation < ApplicationRecord
  extend BelongsToJSONBackedModel

  belongs_to_jbm :employee

  validates_with BelongsToEmployeeValidator
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start
  validate :doesnt_overlap_existing

  default_scope { order(:start_date) }

  after_save :remove_overlapped_work_hours

  def start_date_str
    datestr start_date
  end

  def end_date_str
    datestr end_date
  end

  def overlaps_work_hours?
    not overlapped_work_hours.empty?
  end

  def overlapped_work_hours
    return [] unless valid?
    employee.work_hours.where('hours > 0 AND date BETWEEN ? AND ?', start_date, end_date)
  end

  def self.period_vacations
    Vacation.where(overlap_clause(current_period_start, current_period_end))
  end

  def self.upcoming_vacations
    Vacation.all.where("start_date > ?", current_period_end)
  end

  private

  def datestr(date)
    date.strftime("%-d %b %Y")
  end

  def end_date_after_start
    return if end_date.blank? or start_date.blank?
    errors.add(:end_date, 'after_start_date') if end_date < start_date
  end

  def doesnt_overlap_existing
    return if employee.nil? or start_date.blank? or end_date.blank?
    existing = employee.vacations
    unless existing.where(overlap_clause).empty?
      errors.add(:base, 'Vacation_overlaps')
    end
  end

  def remove_overlapped_work_hours
    overlapped_work_hours.each{ |wh| wh.destroy! }
  end

  def overlap_clause
    Vacation.overlap_clause(start_date, end_date)
  end

  def self.overlap_clause(start_date, end_date)
    ["(start_date BETWEEN :start AND :end) OR
      (end_date BETWEEN :start AND :end) OR
      (start_date < :start AND end_date > :end)",
     {start: start_date, end: end_date}]
  end
end
