class Period
  include Comparable
  attr_reader :year, :month

  def initialize(year, month)
    validate(year, month)
    @year = year
    @month = month
  end

  def validate(year, month)
    unless (1..9999) === year and (1..12) === month
      raise InvalidPeriod
    end
  end

  def start
    Date.new(@year, @month, 1)
  end

  def finish
    (start >> 1) - 1
  end

  def mid_month
    Date.new(@year, @month, 15)
  end

  def length
    finish.day
  end

  def to_range
    (start .. finish)
  end

  def next
    year = @year
    month = @month + 1
    if month > 12
      month = 1
      year = @year + 1
    end
    Period.new(year, month)
  end

  def previous
    year = @year
    month = @month - 1
    if month < 1
      month = 12
      year = @year - 1
    end
    Period.new(year, month)
  end

  def past_january
    Period.new(@year, 1)
  end

  def next_december
    Period.new(@year, 12)
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

  def to_s
    start.strftime("%Y-%m")
  end

  def <=>(other)
    if @year == other.year
      return @month <=> other.month
    else
      return @year <=> other.year
    end
  end

  def self.current
    Period.from_date Date.today
  end

  def self.from_date(date)
    Period.new(date.year, date.month)
  end

  def self.current_as_range
    Period.current.to_range
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

  def self.fr_str(s)
    Period.new(s[0..3].to_i, s[5..6].to_i)
  end
end

class InvalidPeriod < Exception

end
