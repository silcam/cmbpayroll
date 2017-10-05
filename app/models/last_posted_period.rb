class LastPostedPeriod < ApplicationRecord
  validates :year, numericality: {only_integer: true, greater_than: 0, less_than: 10000}
  validates :month, numericality: {only_integer: true, greater_than: 0, less_than: 13}

  def self.get
    period = LastPostedPeriod.first
    return nil if period.nil?
    Period.new period.year, period.month
  end

  def self.current
    last = LastPostedPeriod.get
    return last.next unless last.nil?
    Period.current.previous
  end

  def self.post_current
    period = LastPostedPeriod.current
    posted_period = LastPostedPeriod.first_or_initialize
    posted_period.update year: period.year, month: period.month
    posted_period.save!
  end

  def self.unpost
    period = LastPostedPeriod.get
    return if period.nil?
    period = period.previous
    LastPostedPeriod.first.update year: period.year, month: period.month
  end

  def self.posted?(period)
    period <= LastPostedPeriod.get
  end

  def self.in_posted_period?(*dates)
    dates.each do |date|
      return true if date and date <= LastPostedPeriod.get.finish
    end
    false
  end
end
