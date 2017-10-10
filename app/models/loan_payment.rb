class LoanPayment < ApplicationRecord
  belongs_to :loan

  validates :amount, numericality: { :greater_than_or_equal_to => 1 }
  validate :not_in_posted_period

  def destroyable?
    true if created_in_posted_period
  end

  def destroy
    super if destroyable?
  end

  private

  def not_in_posted_period
    return date_in_posted_period(Date.today)
  end

  def created_in_posted_period
    return date_in_posted_period(created_at)
  end

  def date_in_posted_period(date)
    if date <= LastPostedPeriod.get.finish
      errors.add :date, I18n.t(:cant_be_during_posted_period)
      false
    else
      true
    end
  end
end
