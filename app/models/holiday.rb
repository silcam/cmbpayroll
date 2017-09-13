class Holiday < ApplicationRecord

  validates :name, :date, presence: {message: I18n.t(:Not_blank)}

  default_scope { order(:date) }


  def self.for_year(year)
    where(date: ("#{year}-01-01" .. "#{year}-12-31"))
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
