require "test_helper"

class HolidayTest < ActiveSupport::TestCase

  def setup
    @may20 = holidays :NationalDay
  end

  test "Validations" do
    model_validation_hack_test Holiday, some_valid_params
  end

  test "For Year" do
    assert_includes Holiday.for_year(2017), @may20
    refute_includes Holiday.for_year(2016), @may20
  end

  test "For" do
    assert_includes Holiday.for('2017-05-01', '2017-05-20'), @may20
    refute_includes Holiday.for('2017-05-01', '2017-05-19'), @may20
  end

  test "Days Hash" do
    days = Holiday.days_hash(Date.new(2017, 12, 24), Date.new(2017, 12, 25))
    assert_equal 1, days.length
    assert_equal 'Christmas', days[Date.new(2017, 12, 25)][:holiday]
  end

  test "Generate" do
    Holiday.generate(2018)
    assert Holiday.find_by date: '2018-05-20'
  end

  def some_valid_params(params={})
    {name: 'Christmas', date: '2017-12-25'}.merge(params)
  end
end
