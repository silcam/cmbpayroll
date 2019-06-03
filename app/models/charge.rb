class Charge < ApplicationRecord
  ADVANCE="Salary Advance"

  belongs_to :employee

  validates :amount, numericality: {only_integer: true, message: I18n.t(:Must_be_whole_number)}
  validates :charge_type, presence: true
  validate :date_in_bounds

  enum charge_type: { advance: 0, bank_transfer: 1, other: 2, location_transfer: 3 }

  default_scope { order(:date) }

  def self.for_period(period=Period.current)
    where(date: period.to_range)
  end

  def destroyable?
    date_in_bounds
  end

  def destroy
    super if destroyable?
  end

  private

  def date_in_bounds
    begin
      if date > Date.today
        errors.add :date, I18n.t(:cant_be_in_future)
        false
      elsif date <= LastPostedPeriod.get.finish
        errors.add :date, I18n.t(:cant_be_during_posted_period)
        false
      else
        true
      end
    rescue
      errors.add :date, I18n.t(:is_invalid)
      false
    end
  end
end
