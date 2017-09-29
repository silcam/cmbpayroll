module ApplicationHelper

  def is_weekday?(date)
    (1 .. 5) === date.wday  # TODO Hardcoded workweek as from Mon to Fri
  end

  def is_off_day?(date, holiday)
    (not holiday.nil?) or (not is_weekday?(date))
  end

  def yesterday
    Date.today - 1
  end

  def std_datestring(date)
    date.try(:strftime, "%-d %b %Y")
  end

  def last_monday(date=Date.today)
    diff = date.wday - 1 # 1 == Monday
    diff += 7 if diff < 0
    date - diff
  end

  def next_sunday(date=Date.today)
    last_monday(date) + 6
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

  def options_for_select_plus(collection, value, display, selected, extras)
    array = collection.collect{ |member| [member.send(display), member.send(value)]}
    array += extras
    options_for_select(array, selected)
  end

  # def assemble_date(hash, prefix)
  #   [1, 2, 3].map{ |n| hash["#{prefix}(#{n}i)"]}.join '-'
  # end
end
