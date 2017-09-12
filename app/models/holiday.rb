class Holiday < ApplicationRecord

  default_scope { order(:date) }


  def self.for_year(year)
    where(date: ("#{year}-01-01" .. "#{year}-12-31"))
  end

end
