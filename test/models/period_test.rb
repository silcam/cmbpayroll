require "test_helper"

class PeriodTest < ActiveSupport::TestCase
  def setup
   @july = Period.new(2017, 7)
  end

  test "Constructor" do
    p = Period.new(2017, 9)
    assert_equal 2017, p.year
    assert_equal 9, p.month
  end

  test "Invalid Period" do
    assert_raises (InvalidPeriod) { Period.new(0, 1) }
    assert_raises (InvalidPeriod) { Period.new(10000, 1) }
    assert_raises (InvalidPeriod) { Period.new(2017, 0) }
    assert_raises (InvalidPeriod) { Period.new(2017, 13) }
    assert_raises (InvalidPeriod) { Period.new('2017', 1) }
  end

  test "Start" do
    assert_equal Date.new(2017, 7, 1), @july.start
  end

  test "Mid Month" do
    assert_equal Date.new(2017, 7, 15), @july.mid_month
  end

  test "Finish" do
    assert_equal Date.new(2017, 7, 31), @july.finish
    p = Period.new(2017, 12)
    assert_equal Date.new(2017, 12, 31), p.finish
  end

  test "Length" do
    assert_equal 28, Period.new(2017, 2).length
  end

  test "To Range" do
    assert_equal (Date.new(2017, 7, 1)..Date.new(2017, 7, 31)), @july.to_range
  end

  test "Next" do
    assert_equal Period.new(2017, 8), @july.next
    assert_equal Period.new(2018, 1), Period.new(2017, 12).next
  end

  test "Previous" do
    assert_equal Period.new(2017, 6), @july.previous
    assert_equal Period.new(2016, 12), Period.new(2017, 1).previous
  end

  test "Past January" do
    assert_equal Period.new(2017, 1), @july.past_january
  end

  test "Next December" do
    assert_equal Period.new(2017, 12), @july.next_december
  end

  test "Weekdays" do
    assert_equal 21, @july.weekdays
  end

  test "Month Name" do
    assert_equal "July", @july.month_name
  end

  test "Short Name" do
    assert_equal "Jul 2017", @july.short_name
  end

  test "Name" do
    assert_equal "July 2017", @july.name
  end

  test "To String" do
    assert_equal '2017-07', @july.to_s
  end

  test "Current" do
    Date.stub :today, Date.new(2017, 7, 15) do
      assert_equal @july, Period.current
    end
  end

  test "From Date" do
    assert_equal @july, Period.from_date(Date.new(2017, 7, 22))
  end

  test "Current as Range" do
    Date.stub :today, Date.new(2017, 7, 15) do
      assert_equal (Date.new(2017, 7, 1)..Date.new(2017, 7, 31)), Period.current_as_range
    end
  end

  test "Weekdays so far" do
    Date.stub :today, Date.new(2017, 7, 8) do
      assert_equal 5, Period.weekdays_so_far
    end
  end

  test "Count Weekdays" do
    assert_equal 6, Period.count_weekdays(Date.new(2017, 9, 1), Date.new(2017, 9, 9))
  end

  test "Period from string" do
    assert_equal Period.new(2017, 7), Period.fr_str('2017-07')

    assert_raises (InvalidPeriod){ Period.fr_str('17-07') }
  end
end
