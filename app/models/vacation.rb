class Vacation < ApplicationRecord
  includes BelongsToJSONBackedModel

  belongs_to_jbm :employee

  validates_with BelongsToEmployeeValidator
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start
  validate :doesnt_overlap_existing

  private

  def end_date_after_start
    errors.add(:end_date, 'after_start_date') if end_date < start_date
  end

  def doesnt_overlap_existing
    existing = employee.vacations
    unless existing.where(start_date: (start_date .. end_date)).empty? and
        existing.where(end_date: (start_date .. end_date)).empty?
      errors.add(:base, 'Vacation_overlaps')
    end
  end
end
