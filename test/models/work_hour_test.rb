require "test_helper"

class WorkHourTest < ActiveSupport::TestCase
  def setup
    @luke = employees :Luke
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test WorkHour, some_valid_params
  end

  test "Invalid Date" do
    params = some_valid_params
    params[:date] = 'abc'
    refute WorkHour.new(params).save, "Should not save with invalid date"
    params[:date] = '2017-02-31'
    refute WorkHour.new(params).save, "Should not save with invalid date"
    params[:date] = ''
    refute WorkHour.new(params).save, "Should not save with blank date"
  end

  test "Invalid hours" do
    params = some_valid_params
    params[:hours] = 'a'
    refute WorkHour.new(params).save, "Should not save with invalid hours"
  end

  test "Overlaps Vacation" do
    params = some_valid_params
    params[:date] = '2017-07-01'
    refute WorkHour.new(params).save, "Should not save if date is during vacation"
  end

  def some_valid_params
    {employee: @luke, date: '2017-08-09', hours: 9}
  end
end
