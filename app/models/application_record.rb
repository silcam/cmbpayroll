class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def compute_years_diff(start_date, current_period)
    raise ArgumentError.new("Invalid Start Date") if start_date.nil?
    current_period = Period.current if current_period.nil?

    years = current_period.finish.year - start_date.year
    # if we haven't had our "birthday" yet, reduce the year count by 1
    if current_period.finish.month  < start_date.month ||
         (current_period.finish.month == start_date.month && current_period.finish.day < start_date.day)
      years -= 1
    end
    return years
  end

end
