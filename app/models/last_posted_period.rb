class LastPostedPeriod < ApplicationRecord
  validates :year, numericality: {only_integer: true, greater_than: 0, less_than: 10000}
  validates :month, numericality: {only_integer: true, greater_than: 0, less_than: 13}

  def self.get
    period = LastPostedPeriod.first
    return nil if period.nil?
    Period.new period.year, period.month
  end

  def self.set(year, month)
    period = LastPostedPeriod.first
    if period.nil?
      LastPostedPeriod.create! year: year, month: month
    else
      period.update! year: year, month: month
    end
  end
end
