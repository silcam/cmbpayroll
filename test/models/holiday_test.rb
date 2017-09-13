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

  test "Generate" do
    Holiday.generate(2018)
    assert Holiday.find_by date: '2018-05-20'
  end

  def some_valid_params(params={})
    {name: 'Christmas', date: '2017-12-25'}.merge(params)
  end
end
