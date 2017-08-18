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

  def last_monday
    today = Date.today
    diff = today.wday - 1 # 1 == Monday
    diff += 7 if diff < 0
    today - diff
  end

  def mondays_for_select
    monday = last_monday
    mondays = []
    current = Period.current
    last_two_periods = (current.previous.start .. current.finish)
    while(last_two_periods === monday)
      mondays << [monday.strftime("%d %b") , monday]
      monday += -7
    end
    options_for_select(mondays, mondays[1])
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
