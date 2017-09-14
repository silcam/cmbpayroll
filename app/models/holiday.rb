class Holiday < ApplicationRecord

  validates :name, :date, presence: {message: I18n.t(:Not_blank)}

  default_scope { order(:date) }


  def self.for_year(year)
    Holiday.for(Date.new(year, 1, 1), Date.new(year, 12, 31))
  end

  # Doesn't check bridge and observed fields
  def self.for(start, finish)
    where(date: (start .. finish))
  end

  def self.days_hash(start, finish)
    holidays = Holiday.where("date BETWEEN :start AND :finish OR
                              observed BETWEEN :start AND :finish OR
                              bridge BETWEEN :start AND :finish",
                             {start: start, finish: finish})
    days = {}
    holidays.each do |holiday|
      days[holiday.date] = {holiday: holiday.name} if (start .. finish) === holiday.date
      days[holiday.observed] = {holiday: "#{holiday.name} #{I18n.t(:Observed)}"} if (start .. finish) === holiday.observed
      days[holiday.bridge] = {holiday: "#{holiday.name} #{I18n.t(:Bridge)}"} if (start .. finish) === holiday.bridge
    end
    days
  end

  def self.generate(year)
    Holiday.for_year(year - 1).each do |holiday|
      new_date = holiday.date.next_year
      observed = new_date.sunday? ? new_date + 1 : nil
      observed = nil if holiday.name == 'Easter'
      Holiday.create(name: holiday.name, date: new_date, observed: observed)
    end
  end
end
