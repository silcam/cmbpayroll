require "test_helper"

class WorkHourTest < ActiveSupport::TestCase
  def setup
    @luke = employees :Luke
    @lukes_overtime = work_hours :LukesOvertime
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

  test "Current Period" do
    refute_includes WorkHour.current_period, @lukes_overtime
    Date.stub :today, Date.new(2017, 8, 31) do
      assert_includes WorkHour.current_period, @lukes_overtime
    end
  end

  test "Total Hours for August" do
    exp = {normal: 176, overtime: 2}
    assert_equal exp, WorkHour.total_hours(@luke, Period.new(2017, 8))
  end

  test "Total Hours So Far" do
    Date.stub :today, Date.new(2017,8,11) do
      exp = {normal: 56, overtime: 2}
      assert_equal exp, WorkHour.total_hours_so_far(@luke)
    end
  end

  test "Total Hours with holiday" do
    exp = {normal: (20 * 8), overtime: 0}
    assert_equal exp, WorkHour.total_hours(@luke, Period.new(2017, 12))

    WorkHour.create(employee: @luke, date: '2017-12-25', hours: 2)
    exp[:overtime] = 2
    assert_equal exp, WorkHour.total_hours(@luke, Period.new(2017, 12))
  end

  test "Lukes Week of Aug 7, 2017" do
    week = WorkHour.week_for @luke, Date.new(2017, 8, 8)
    assert_equal @lukes_overtime, week.first
    assert_equal Date.new(2017, 8, 13), week.last.date
    assert week[2].new_record?
    assert_equal 8, week[2].hours
    assert_equal 0, week.last.hours
  end

  test "Update" do
    hours = {'2017-08-07'=>'8', '2017-08-08'=>'12', '2017-08-09'=>'9', '2017-08-10'=>'8'}
    WorkHour.update @luke, hours
    assert_nil @luke.work_hours.find_by(date: '2017-08-07'), "This should have been deleted"
    assert_nil @luke.work_hours.find_by(date: '2017-08-10'), "This should not have been created"
    assert_equal 12, @luke.work_hours.find_by(date: '2017-08-08').hours
    assert_equal 9, @luke.work_hours.find_by(date: '2017-08-09').hours
  end

  test "Validate Valid Hours" do
    hours = {'2017-08-31'=>'8.1', '2017-09-01'=>'24', '2017-09-02'=>'0'}
    assert_nil WorkHour.validate_hours!(hours), "Should run without raising an exception"
  end

  test "Validate Invalid Hours" do
    hours = {'2017-08-31'=>'-1', '2017-09-01'=>'25', '2017-09-02'=>'two'}
    begin
      WorkHour.validate_hours! hours
      assert false # An exception must be thrown
    rescue InvalidHoursException => e
      assert_equal 3, e.errors.count
    else
      assert false # Expecting an InvalidHoursException
    end
  end

  test "Default Hours" do
    assert_equal 8, WorkHour.default_hours(Date.new(2017, 9, 5))
    assert_equal 0, WorkHour.default_hours(Date.new(2017, 9, 9))
  end

  test "Default Hours?" do
    assert WorkHour.default_hours?(Date.new(2017, 9, 5), '8')
    refute WorkHour.default_hours?(Date.new(2017, 9, 5), '9')
  end

  def some_valid_params
    {employee: @luke, date: '2017-08-09', hours: 9}
  end
end
