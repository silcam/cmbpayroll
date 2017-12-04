class MiscPayment < ApplicationRecord

  belongs_to :employee

  validates :amount, numericality: {only_integer: true}
  validate :date_in_bounds

  default_scope{ order(:date) }

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
