class Period
  attr_reader :year, :month

  def initialize(year, month)
    @year = year
    @month = month
  end

  def start
    Date.new(@year, @month, 1)
  end

  def finish
    Date.new(@year, @month + 1, 1) - 1
  end

  def weekdays
    Period.count_weekdays(start, finish)
  end

  def month_name
    start.strftime("%B")
  end

  def short_name
    start.strftime("%b %Y")
  end

  def name
    start.strftime("%B %Y")
  end

  def self.current
    today = Date.today
    Period.new(today.year, today.month)
  end

  def self.current_as_range
    c = Period.current
    (c.start .. c.finish)
  end

  def self.weekdays_so_far
    count_weekdays(Period.current.start, Date.today - 1)
  end

  def self.count_weekdays(d1, d2)
    weekdays = 0
    (d1 .. d2).each do |d|
      weekdays += 1 if is_weekday?(d)
    end
    weekdays
  end

end