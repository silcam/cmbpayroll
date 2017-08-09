class WorkHour < ApplicationRecord
  include BelongsToJSONBackedModel

  belongs_to_jbm :employee

  validates_with BelongsToEmployeeValidator
  validates :date, presence: true
  validates :hours, numericality: true
  validate :not_during_vacation

  private

  def not_during_vacation
    unless employee.vacations.
        where("start_date <= :date AND end_date >= :date", {date: date}).
        empty?
      errors.add(:date, 'not_during_vacation')
    end
  end
end
