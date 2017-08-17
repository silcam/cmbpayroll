module ApplicationHelper

  # def current_period_name
  #   Date.today.strftime("%B")
  # end
  #
  # def current_period_start
  #   today = Date.today
  #   Date.new(today.year, today.month, 1)
  # end
  #
  # def current_period_end
  #   current_period_start.next_month - 1
  # end
  #
  def is_weekday?(date)
    (1 .. 5) === date.wday
  end

  def yesterday
    Date.today - 1
  end

  def std_datestring(date)
    date.strftime("%-d %b %Y")
  end
  #
  #
  #
  # def current_period_weekdays_so_far
  #   count_weekdays current_period_start, (Date.today - 1)
  # end

  # def assemble_date(hash, prefix)
  #   [1, 2, 3].map{ |n| hash["#{prefix}(#{n}i)"]}.join '-'
  # end
end
