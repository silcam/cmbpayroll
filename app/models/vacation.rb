class Vacation < ApplicationRecord
  extend BelongsToJSONBackedModel

  belongs_to_jbm :employee

  validates_with BelongsToEmployeeValidator
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start
  validate :doesnt_overlap_existing

  after_save :remove_overlapped_work_hours

  def overlaps_work_hours?
    not overlapped_work_hours.empty?
  end

  def overlapped_work_hours
    return [] unless valid?
    employee.work_hours.where('hours > 0 AND date BETWEEN ? AND ?', start_date, end_date)
  end

  def self.period_vacations

  end

  def self.upcoming_vacations

  end

  private

  def end_date_after_start
    return if end_date.blank? or start_date.blank?
    errors.add(:end_date, 'after_start_date') if end_date < start_date
  end

  def doesnt_overlap_existing
    return if employee.nil? or start_date.blank? or end_date.blank?
    existing = employee.vacations
    unless existing.where("start_date <= :date AND end_date >= :date", {date: start_date}).empty? and
        existing.where("start_date <= :date AND end_date >= :date", {date: end_date}).empty?
      errors.add(:base, 'Vacation_overlaps')
    end
  end

  def remove_overlapped_work_hours
    overlapped_work_hours.each{ |wh| wh.destroy! }
  end
end
