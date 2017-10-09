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
    params[:date] = '2018-02-31'
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

  test "Inside the posted period" do
    # Posted period is July 2017
    refute WorkHour.create(some_valid_params.merge(date: '2017-07-31')).persisted?
    assert WorkHour.create(some_valid_params.merge(date: '2017-08-01')).persisted?
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

  test "Total Hours with holiday" do
    exp = WorkHour.total_hours(@luke, Period.new(2017, 8))

    Holiday.create!(name: 'Ascension', date: '2017-08-14')
    exp[:normal] += -8
    exp[:holiday] = 8
    assert_equal exp, WorkHour.total_hours(@luke, Period.new(2017, 8))
  end

  test "Total Hours with Vacation" do
    exp = WorkHour.total_hours(@luke, Period.new(2017, 8))
    @luke.vacations.create!(start_date: '2017-08-14', end_date: '2017-08-18')
    exp[:normal] += (-1 * 8 * 5)
    assert_equal exp, WorkHour.total_hours(@luke, Period.new(2017, 8))
  end

  test "Lukes Week of Aug 7, 2017" do
    week = WorkHour.days_hash_for_week @luke, Date.new(2017, 8, 8)
    assert_equal 7, week.length
    assert_equal (Date.new(2017, 8, 7)..Date.new(2017, 8, 13)).to_a, week.keys
    assert_equal 10, week[Date.new(2017, 8, 7)][:hours]
    assert_equal 8, week[Date.new(2017, 8, 9)][:hours]
    assert_equal 0, week[Date.new(2017, 8, 13)][:hours]
  end

  test "Update" do
    hours = {'2017-08-07'=>'8', '2017-08-08'=>'12', '2017-08-09'=>'9', '2017-08-10'=>'8'}
    WorkHour.update @luke, hours, {'2017-08-11'=>'1'}
    assert_equal 8,  @luke.work_hours.find_by(date: '2017-08-07').hours, "This should have been updated"
    assert_equal 8, @luke.work_hours.find_by(date: '2017-08-10').hours, "This should have been created"
    assert_equal 12, @luke.work_hours.find_by(date: '2017-08-08').hours
    assert_equal 9, @luke.work_hours.find_by(date: '2017-08-09').hours
    sickday = @luke.work_hours.find_by(date: '2017-08-11')
    assert_equal 0, sickday.hours
    assert sickday.sick
  end

  test "Employees Lacking Work Hours" do
    chewie = employees :Chewie
    employees = WorkHour.employees_lacking_work_hours(Period.new(2017, 8))
    assert_includes employees, chewie
    refute_includes employees, @luke
  end

  test "Validate Valid Hours" do
    hours = {'2017-08-31'=>'8.1', '2017-09-01'=>'24', '2017-09-02'=>'0'}
    success, errors = WorkHour.update @luke, hours, {}
    assert success, "Should run without raising an exception"
  end

  test "Validate Invalid Hours" do
    hours = {'2017-08-31'=>'-1', '2017-09-01'=>'25', '2017-09-02'=>'two'}
    success, errors = WorkHour.update @luke, hours, {}
    refute success, "Update should not succeed with invalid hours"
    assert_equal 3, errors.count
  end

  test "Default Hours" do
    assert_equal 8, WorkHour.default_hours(Date.new(2017, 9, 5), nil)
    assert_equal 0, WorkHour.default_hours(Date.new(2017, 9, 9), nil)
  end

  test "Default Hours?" do
    assert WorkHour.default_hours?(Date.new(2017, 9, 5), nil, '8')
    refute WorkHour.default_hours?(Date.new(2017, 9, 5), nil, '9')
  end

  test "Calculate Overtime" do
    exp = {normal: 8}
    day = {hours: 8}
    assert_equal exp, WorkHour.calculate_overtime( Date.new(2017, 9, 21), day)

    exp = {holiday: 8}
    day = {hours: 8, holiday: 'Talk like a Pirate Day'}
    assert_equal exp, WorkHour.calculate_overtime( Date.new(2017, 9, 20), day)

    exp = {holiday: 12}
    day = {hours: 12}
    assert_equal exp, WorkHour.calculate_overtime( Date.new(2017, 9, 17), day)

    exp = {normal: 6}
    day = {hours: 6}
    assert_equal exp, WorkHour.calculate_overtime( Date.new(2017, 9, 21), day)

    exp = {normal: 8, overtime: 4}
    day = {hours: 12}
    assert_equal exp, WorkHour.calculate_overtime( Date.new(2017, 9, 21), day)
  end

  def some_valid_params
    {employee: @luke, date: '2017-08-09', hours: 9}
  end
end
