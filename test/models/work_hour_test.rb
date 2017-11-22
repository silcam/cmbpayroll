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

  test "Days and Hours Worked with Sick" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    luke_days_hash = WorkHour.days_hash(@luke, jan.start, jan.finish)
    assert_equal(0, luke_days_hash.keys.size, "should not have worked in jan yet")

    sickhours = { "2018-01-02" => 8 }

    WorkHour.update(@luke, {}, sickhours)
    luke_days_hash = WorkHour.days_hash(@luke, jan.start, jan.finish)
    assert_equal(1, luke_days_hash.keys.size, "1 day worked")

    assert(luke_days_hash[Date.new(2018,1,2)][:hours], "02 Jan should be 0 hours")
    assert(luke_days_hash[Date.new(2018,1,2)][:sick], "02 Jan should be sick time")

    hours_worked, days_worked = WorkHour.compute_hours_and_days(@luke, jan)
    assert_equal(1, days_worked, "sick time is a day")
    assert_equal(8, hours_worked, "sick time is 8 hours")
  end

  test "Days and Hours Worked" do
    dec = Period.new(2017,12)
    @luke.days_week = "five"

    luke_days_hash = WorkHour.days_hash(@luke, dec.start, dec.finish)
    assert_equal(0, luke_days_hash.keys.size, "should not have worked in dec yet")

    #   December 2017      
    #Su Mo Tu We Th Fr Sa  
    #                1  2  
    # 3  4  5  6  7  8  9  
    #10 11 12 13 14 15 16  
    #17 18 19 20 21 22 23  
    #24 25 26 27 28 29 30  
    #31

    hours = {
      "2017-12-01" => 8,
      "2017-12-04" => 8,
      "2017-12-05" => 8,
      "2017-12-06" => 8,
      "2017-12-07" => 8,
      "2017-12-08" => 8
    }

    success, errors = WorkHour.update(@luke, hours, {})
    assert(success, "should not have produced these errors: #{errors.inspect}")

    luke_days_hash = WorkHour.days_hash(@luke, dec.start, dec.finish)
    assert_equal(6, luke_days_hash.keys.size, "should have worked 5 days")

    # plus 12/25
    assert_equal(7, WorkHour.days_worked(@luke, dec))
    assert_equal(56, WorkHour.hours_worked(@luke, dec))

    hours = {
      "2017-12-01" => 8,
      "2017-12-04" => 8,
      "2017-12-05" => 8,
      "2017-12-06" => 8,
      "2017-12-07" => 8,
      "2017-12-08" => 8,
      "2017-12-11" => 8
    }

    success, errors = WorkHour.update(@luke, hours, {})
    assert(success, "should not have produced these errors: #{errors.inspect}")

    # plus 12/25
    assert_equal(8, WorkHour.days_worked(@luke, dec))
    assert_equal(64, WorkHour.hours_worked(@luke, dec))

    holiday = Holiday.create!(name: "Dec 12", date: "2017-12-12")

    cdh = WorkHour.complete_days_hash(@luke, dec.start, dec.finish)

    # Holidays should count as days worked.
    # plus 12/12 and 12/25
    assert_equal(9, WorkHour.days_worked(@luke, dec))
    assert_equal(72, WorkHour.hours_worked(@luke, dec))
  end

  test "Hours Worked" do
    dec = Period.new(2017,12)
    @luke.days_week = "five"

    # 34 including Christmas
    hours = {
      "2017-12-01" => 4,
      "2017-12-04" => 2,
      "2017-12-05" => 3,
      "2017-12-06" => 4,
      "2017-12-07" => 5,
      "2017-12-08" => 7,
      "2017-12-11" => 1
    }

    success, errors = WorkHour.update(@luke, hours, {})
    assert(success, "should not have produced these errors: #{errors.inspect}")

    # plus 12/25
    assert_equal(34, WorkHour.hours_worked(@luke, dec))
  end

  test "Worked Full Month by days" do
    dec = Period.new(2017,12)
    @luke.days_week = "five"

    luke_days_hash = WorkHour.days_hash(@luke, dec.start, dec.finish)
    assert_equal(0, luke_days_hash.keys.size, "should not have worked in dec yet")
    refute(WorkHour.worked_full_month(@luke, dec))

    hours = {
      "2017-12-01" => 8,

      "2017-12-04" => 8,
      "2017-12-05" => 8,
      "2017-12-06" => 8,
      "2017-12-07" => 8,
      "2017-12-08" => 8
    }

    success, errors = WorkHour.update(@luke, hours, {})
    assert(success, "should not have produced these errors: #{errors.inspect}")
    # plus 12/25
    assert_equal(7, WorkHour.days_worked(@luke, dec))
    refute(WorkHour.worked_full_month(@luke, dec))

    hours = {
      "2017-12-01" => 8,

      "2017-12-04" => 8,
      "2017-12-05" => 8,
      "2017-12-06" => 8,
      "2017-12-07" => 8,
      "2017-12-08" => 8,

      "2017-12-11" => 8,
      "2017-12-12" => 8,
      "2017-12-13" => 8,
      "2017-12-14" => 8,
      "2017-12-15" => 8,

      "2017-12-16" => 8,
      "2017-12-17" => 8,
      "2017-12-18" => 8,
      "2017-12-19" => 8,
      "2017-12-20" => 8,

      "2017-12-23" => 8,
      "2017-12-24" => 8,
      #"2017-12-24" => 8 #Holiday
      "2017-12-26" => 8,
      "2017-12-27" => 8,

      "2017-12-30" => 8,
      "2017-12-31" => 8
    }
    success, errors = WorkHour.update(@luke, hours, {})
    assert(success, "should not have produced these errors: #{errors.inspect}")

    # plus 12/25
    assert_equal(23, WorkHour.days_worked(@luke, dec))

    # by days
    assert(WorkHour.worked_full_month(@luke, dec))
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

  test "Overtime Summary" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    generate_work_hours(@luke, jan)

    # no overtime
    exp = {normal: 184}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  test "<8 hours (6) Overtime Summary" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    generate_work_hours(@luke, jan)

    hours = {
      "2018-01-01" => 10,
      "2018-01-04" => 10,
      "2018-01-08" => 10,
    }

    # 6 hours overtime
    WorkHour.update(@luke, hours, {})
    exp = {normal: 184, overtime: 6}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  test "36 hours Overtime Summary" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    generate_work_hours(@luke, jan)

    hours = {
      "2018-01-01" => 12, "2018-01-04" => 12,
      "2018-01-08" => 12, "2018-01-11" => 12,
      "2018-01-15" => 12, "2018-01-18" => 12,
      "2018-01-22" => 12, "2018-01-25" => 12,
      "2018-01-29" => 12
    }

    # 36 hours ot
    WorkHour.update(@luke, hours, {})
    # Old Logic. Overtime tranche calculation is now in Payslip.overtime_tranches()
    # exp = {normal: 184, overtime: 8, overtime2: 8, overtime3: 20}
    exp = {normal: 184, overtime: 36}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  test "Sunday hours are OT3 Overtime Summary" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    generate_work_hours(@luke, jan)

    hours = {
      "2018-01-07" => 10 # 4 hours sunday OT
    }

    WorkHour.update(@luke, hours, {})
    exp = {normal: 184.0, holiday: 10.0}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  test "Holiday hours are OT3 Overtime Summary" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    generate_work_hours(@luke, jan)

    Holiday.create!(name: "New Years", date: '2018-01-01')

    hours = {
      "2018-01-01" => 12 # hours holiday OT
    }

    WorkHour.update(@luke, hours, {})
    exp = {normal: 176.0,  holiday: 12}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  def some_valid_params
    {employee: @luke, date: '2017-08-09', hours: 9}
  end
end
