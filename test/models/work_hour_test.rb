require "test_helper"

class WorkHourTest < ActiveSupport::TestCase
  def setup
    @luke = employees :Luke
    @lukes_overtime = work_hours :LukesOvertime
    @admin = departments :Admin
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
    exp = {normal: (20 * 8)}
    assert_equal exp, WorkHour.total_hours(@luke, Period.new(2017, 12))

    WorkHour.create(employee: @luke, date: '2017-12-25', hours: 2)
    exp[:holiday] = 2
    assert_equal exp, WorkHour.total_hours(@luke, Period.new(2017, 12))
  end

  test "Total Hours with Vacation" do
    exp = {normal: (17 * 8)} # 5 days of vacation from the 5th to 9th
    assert_equal exp, WorkHour.total_hours(employees(:Anakin), Period.new(2017, 6))
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

  test "Can Override Dept" do

    employee0 = return_valid_employee()

    dept0 = Department.new
    dept0.name = random_string(15)
    dept0.description = dept0.name
    dept0.account = "dept0"

    employee0.department = dept0
    employee0.save

    employee1 = return_valid_employee()

    hours = {'2017-08-07'=>'6',
             '2017-08-08'=>'5',
             '2017-08-09'=>'9',
             '2017-08-10'=>'7'}

    depts = {'2017-08-08'=>dept0.id}

    WorkHour.update employee1, hours, depts

    assert_equal 6, employee1.work_hours.find_by(date: '2017-08-07').hours
    assert_equal 5, employee1.work_hours.find_by(date: '2017-08-08').hours
    assert_equal 9, employee1.work_hours.find_by(date: '2017-08-09').hours
    assert_equal 7, employee1.work_hours.find_by(date: '2017-08-10').hours

    assert_equal(dept0.id, employee1.work_hours.find_by(date: '2017-08-08').department_id)
  end

  test "merge hours and dept hashes" do
    hours = {'2017-08-01'=>'5',
             '2017-08-02'=>'7',
             '2017-08-03'=>'2',
             '2017-08-04'=>'8'}

    loans = {'2017-08-03'=>'TESTDEPT'}

    merged_hash = WorkHour.merge_hashes(hours, loans)

    assert_equal('5', merged_hash['2017-08-01'])
    assert_equal('7', merged_hash['2017-08-02'])
    assert_equal('8', merged_hash['2017-08-04'])

    assert_equal('2', merged_hash['2017-08-03']['hours'])
    assert_equal('TESTDEPT', merged_hash['2017-08-03']['dept'])
  end

  test "merge hours with null results in hash" do
    hours = {'2017-08-01'=>'5',
             '2017-08-02'=>'7',
             '2017-08-03'=>'2',
             '2017-08-04'=>'8'}

    merged_hash = WorkHour.merge_hashes(hours, nil)

    assert_equal('5', merged_hash['2017-08-01'])
    assert_equal('7', merged_hash['2017-08-02'])
    assert_equal('2', merged_hash['2017-08-03'])
    assert_equal('8', merged_hash['2017-08-04'])
  end

  test "Merge hours and dept hashes without overlap" do
    hours = {'2017-08-01'=>'5',
             '2017-08-02'=>'7',
             '2017-08-04'=>'8'}

    loans = {'2017-08-03'=>'TESTDEPT'}

    merged_hash = WorkHour.merge_hashes(hours, loans)

    assert_equal('5', merged_hash['2017-08-01'])
    assert_equal('7', merged_hash['2017-08-02'])
    assert_equal('8', merged_hash['2017-08-04'])

    assert_equal('8', merged_hash['2017-08-03']['hours'])
    assert_equal('TESTDEPT', merged_hash['2017-08-03']['dept'])
  end

  test "cannot loan to own department" do
    employee = return_valid_employee()

    dept = Department.new
    dept.name = random_string(15)
    dept.description = dept.name
    dept.account = "4444H"

    employee.department = dept
    employee.save

    hours = {'2017-08-07'=>'6',
             '2017-08-08'=>'5',
             '2017-08-09'=>'9',
             '2017-08-10'=>'7'}

    depts = {'2017-08-08'=>dept.id}

    WorkHour.update employee, hours, depts

    assert_equal 6, employee.work_hours.find_by(date: '2017-08-07').hours
    assert_equal 5, employee.work_hours.find_by(date: '2017-08-08').hours
    assert_equal 9, employee.work_hours.find_by(date: '2017-08-09').hours
    assert_equal 7, employee.work_hours.find_by(date: '2017-08-10').hours

    assert_nil(employee.work_hours.find_by(date: '2017-08-08').department_id,
        "should be nil, an overridden department shouldn't be saved if own department")
  end

  def some_valid_params
    {employee: @luke, date: '2017-08-09', hours: 9}
  end
end
