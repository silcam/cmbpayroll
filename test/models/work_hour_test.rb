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
    hours = {'2017-08-07'=>{hours: '8'},
             '2017-08-08'=>{hours:'12'},
             '2017-08-09'=>{hours:'9'},
             '2017-08-10'=>{hours:'8'},
              '2017-08-11'=>{hours:'0', excused_hours:'8', excuse:'Sick'}}
    WorkHour.update @luke, hours
    assert_equal 8,  @luke.work_hours.find_by(date: '2017-08-07').hours, "This should have been updated"
    assert_equal 8, @luke.work_hours.find_by(date: '2017-08-10').hours, "This should have been created"
    assert_equal 12, @luke.work_hours.find_by(date: '2017-08-08').hours
    assert_equal 9, @luke.work_hours.find_by(date: '2017-08-09').hours
    sickday = @luke.work_hours.find_by(date: '2017-08-11')
    assert_equal 0, sickday.hours
    assert_equal 8, sickday.excused_hours
  end

  test "Days and Hours Worked with Sick" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    luke_days_hash = WorkHour.days_hash(@luke, jan.start, jan.finish)
    assert_equal(0, luke_days_hash.keys.size, "should not have worked in jan yet")

    # sickhours = { "2018-01-02" => {hours: 8} }

    WorkHour.update(@luke, {"2018-01-02"=>{hours: '', excused_hours: 8, excuse: 'Sick'}})
    luke_days_hash = WorkHour.days_hash(@luke, jan.start, jan.finish)
    assert_equal(1, luke_days_hash.keys.size, "1 day worked")

    assert(luke_days_hash[Date.new(2018,1,2)][:hours], "02 Jan should be 0 hours")
    assert_equal('Sick',luke_days_hash[Date.new(2018,1,2)][:excuse], "02 Jan should be sick time")

    hours_worked, days_worked = WorkHour.compute_hours_and_days(@luke, jan)
    assert_equal(1, days_worked, "sick time is a day")
    assert_equal(8, hours_worked, "sick time is 8 hours")
  end

  test "Days and Hours should return 0 if no work" do
    @luke.days_week = "five"
    dec18 = Period.new(2018,12)

    assert_equal(0, @luke.work_hours.where("date BETWEEN ? AND ?",
        dec18.start, dec18.finish).count(),
          "no work hours in period")

    hours_worked, days_worked = WorkHour.compute_hours_and_days(@luke, dec18)

    assert_equal(0, days_worked, "0 when no work")
    assert_equal(0, hours_worked, "0 when no work")

    days_worked = WorkHour.days_worked(@luke, dec18)
    hours_worked = WorkHour.hours_worked(@luke, dec18)

    assert_equal(0, days_worked, "0 when no work")
    assert_equal(0, hours_worked, "0 when no work")
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
      "2017-12-01" => {hours: 8},
      "2017-12-04" => {hours: 8},
      "2017-12-05" => {hours: 8},
      "2017-12-06" => {hours: 8},
      "2017-12-07" => {hours: 8},
      "2017-12-08" => {hours: 8}
    }

    success, errors = WorkHour.update(@luke, hours)
    assert(success, "should not have produced these errors: #{errors.inspect}")

    luke_days_hash = WorkHour.days_hash(@luke, dec.start, dec.finish)
    assert_equal(6, luke_days_hash.keys.size, "should have worked 5 days")

    # plus 12/25
    assert_equal(7, WorkHour.days_worked(@luke, dec))
    assert_equal(56, WorkHour.hours_worked(@luke, dec))

    hours = {
      "2017-12-01" => {hours: 8},
      "2017-12-04" => {hours: 8},
      "2017-12-05" => {hours: 8},
      "2017-12-06" => {hours: 8},
      "2017-12-07" => {hours: 8},
      "2017-12-08" => {hours: 8},
      "2017-12-11" => {hours: 8}
    }

    success, errors = WorkHour.update(@luke, hours)
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
      "2017-12-01" => {hours: 4},
      "2017-12-04" => {hours: 2},
      "2017-12-05" => {hours: 3},
      "2017-12-06" => {hours: 4},
      "2017-12-07" => {hours: 5},
      "2017-12-08" => {hours: 7},
      "2017-12-11" => {hours: 1}
    }

    success, errors = WorkHour.update(@luke, hours)
    assert(success, "should not have produced these errors: #{errors.inspect}")

    # plus 12/25
    assert_equal(34, WorkHour.hours_worked(@luke, dec))
  end

  test "Worked Full Month by days" do
    dec = Period.new(2017,12)
    @luke.days_week = "five"
    @luke.wage_period = "monthly"

    luke_days_hash = WorkHour.days_hash(@luke, dec.start, dec.finish)
    assert_equal(0, luke_days_hash.keys.size, "should not have worked in dec yet")
    refute(WorkHour.worked_full_month(@luke, dec))

    hours = {
      "2017-12-01" => {hours: 8},

      "2017-12-04" => {hours: 8},
      "2017-12-05" => {hours: 8},
      "2017-12-06" => {hours: 8},
      "2017-12-07" => {hours: 8},
      "2017-12-08" => {hours: 8}
    }

    success, errors = WorkHour.update(@luke, hours)
    assert(success, "should not have produced these errors: #{errors.inspect}")
    # plus 12/25
    assert_equal(7, WorkHour.days_worked(@luke, dec))
    refute(WorkHour.worked_full_month(@luke, dec))

    hours = {
      "2017-12-01" => {hours: 8},

      "2017-12-04" => {hours: 8},
      "2017-12-05" => {hours: 8},
      "2017-12-06" => {hours: 8},
      "2017-12-07" => {hours: 8},
      "2017-12-08" => {hours: 8},

      "2017-12-11" => {hours: 8},
      "2017-12-12" => {hours: 8},
      "2017-12-13" => {hours: 8},
      "2017-12-14" => {hours: 8},
      "2017-12-15" => {hours: 8},

      "2017-12-18" => {hours: 8},
      "2017-12-19" => {hours: 8},
      "2017-12-20" => {hours: 8},
      "2017-12-21" => {hours: 8},
      "2017-12-22" => {hours: 8},

      #"2017-12-25" => 8 #Holiday
      "2017-12-26" => {hours: 8},
      "2017-12-27" => {hours: 8},
      "2017-12-28" => {hours: 8},
      "2017-12-29" => {hours: 8}
    }
    success, errors = WorkHour.update(@luke, hours)
    assert(success, "should not have produced these errors: #{errors.inspect}")

    # plus 12/25 (only 21 working days and holidays in December)
    assert_equal(21, WorkHour.days_worked(@luke, dec))
    assert_equal(21, @luke.workdays_per_month(dec), "correct number of days in Dec")

    # by days
    assert(@luke.paid_monthly?)
    assert(WorkHour.worked_full_month(@luke, dec))
  end

  test "Days Worked should only include work week (Overtime on Saturday is just overtime)" do
    period= Period.new(2018,2)
    @luke.days_week = "five"

    generate_work_hours(@luke, period)

    # 20 working days, plus 2 16 hour Saturdays
    hours = {
      "2018-02-03" => {hours: 16},
      "2018-02-10" => {hours: 16},
    }

    success, errors = WorkHour.update(@luke, hours)
    assert(success, "should not have produced these errors: #{errors.inspect}")

    assert_equal(20, WorkHour.days_worked(@luke, period))
    assert(WorkHour.worked_full_month(@luke, period))
  end

  test "Employees Lacking Work Hours" do
    chewie = employees :Chewie
    employees = WorkHour.employees_lacking_work_hours(Period.new(2017, 8))
    assert_includes employees, chewie
    refute_includes employees, @luke
  end

  test "Validate Valid Hours" do
    hours = {'2017-08-31'=>{hours: '8.1'}, '2017-09-01'=>{hours: '24'}, '2017-09-02'=>{hours:'0'}}
    success, errors = WorkHour.update @luke, hours
    assert success, "Should run without raising an exception"
  end

  test "Validate Invalid Hours" do
    hours = {'2017-08-31'=>{hours: '-1'}, '2017-09-01'=>{hours: '25'}}
    success, errors = WorkHour.update @luke, hours
    refute success, "Update should not succeed with invalid hours"
    assert_equal 2, errors.count
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
      "2018-01-01" => {hours: 10},
      "2018-01-04" => {hours: 10},
      "2018-01-08" => {hours: 10},
    }

    # 6 hours overtime
    WorkHour.update(@luke, hours)
    exp = {normal: 184, overtime: 6}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  test "36 hours Overtime Summary" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    generate_work_hours(@luke, jan)

    hours = {
      "2018-01-01" => {hours: 12}, "2018-01-04" => {hours: 12},
      "2018-01-08" => {hours: 12}, "2018-01-11" => {hours: 12},
      "2018-01-15" => {hours: 12}, "2018-01-18" => {hours: 12},
      "2018-01-22" => {hours: 12}, "2018-01-25" => {hours: 12},
      "2018-01-29" => {hours: 12}
    }

    # 36 hours ot
    WorkHour.update(@luke, hours)
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
      "2018-01-07" => {hours: 10} # 4 hours sunday OT
    }

    WorkHour.update(@luke, hours)
    exp = {normal: 184.0, holiday: 10.0}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  test "Holiday hours are OT3 Overtime Summary" do
    jan = Period.new(2018,1)
    @luke.days_week = "five"

    generate_work_hours(@luke, jan)

    Holiday.create!(name: "New Years", date: '2018-01-01')

    hours = {
      "2018-01-01" => {hours: 12} # hours holiday OT
    }

    WorkHour.update(@luke, hours)
    exp = {normal: 176.0,  holiday: 12}
    assert_equal(exp, WorkHour.total_hours(@luke, jan))
  end

  test "Sunday holidays don't count as working days with vacation" do
    employee = return_valid_employee()
    period = Period.new(2018,2)

    Holiday.all.delete_all
    holiday = Holiday.create!(name: 'Youth Day', date: '2018-02-18', observed: '2018-02-19')
    assert(holiday)
    vacation = Vacation.create(start_date: '2018-02-01', end_date: '2018-02-28', employee: employee)
    assert(vacation)

    assert_equal(1, WorkHour.days_worked(employee, period), "should have worked one day")
  end

  test "Sunday holidays don't count as working days without vacation" do
    employee = return_valid_employee()
    period = Period.new(2018,2)

    Holiday.all.delete_all
    holiday = Holiday.create!(name: 'Youth Day', date: '2018-02-18', observed: '2018-02-19')
    assert(holiday)

    generate_work_hours(employee, period)

    hours = {
      "2018-02-19" => {hours:0} # didn't work on Youth day, slacker.
    }

    assert_equal(20, WorkHour.days_worked(employee, period), "should have worked full month")
  end

  test "Fill Work Hours" do
    employee = return_valid_employee()

    period = LastPostedPeriod.current
    refute(LastPostedPeriod.posted?(period), "should not be posted")

    employees_list = WorkHour.employees_lacking_work_hours(period)
    assert(employees_list.include?(employee), "should not have hours")
    refute(WorkHour.worked_full_month(employee, period), "didn't work yet")

    WorkHour.fill_default_hours(employee, period)

    employees_list = WorkHour.employees_lacking_work_hours(period)
    refute(employees_list.include?(employee), "should have hours now")
    assert(WorkHour.worked_full_month(employee, period), "now worked")
  end

  test "Fill work hours with no unfilled days does nothing" do
    employee = return_valid_employee()
    period = LastPostedPeriod.current

    employees_list = WorkHour.employees_lacking_work_hours(period)
    assert(employees_list.include?(employee), "should not have hours")

    WorkHour.fill_default_hours(employee, period)

    employees_list = WorkHour.employees_lacking_work_hours(period)
    refute(employees_list.include?(employee), "should have hours now")
    assert(WorkHour.worked_full_month(employee, period), "now worked")

    WorkHour.fill_default_hours(employee, period)

    employees_list = WorkHour.employees_lacking_work_hours(period)
    refute(employees_list.include?(employee), "should have hours now")
    assert(WorkHour.worked_full_month(employee, period), "now worked")
  end

  test "Fill work hours with vacation is fine" do
    employee = return_valid_employee()
    period = LastPostedPeriod.current

    vacation = Vacation.create(
        start_date: period.start,
        end_date: period.mid_month,
        employee: employee
    )
    assert(vacation)

    WorkHour.fill_default_hours(employee, period)

    # verify no vacation days have hours
    (period.start .. period.mid_month).each do |vac_day|
      next if (vac_day.saturday? || vac_day.sunday?)

      assert(Vacation.on_vacation_during(employee, vac_day, vac_day), "vacation day")
      assert(WorkHour.total_hours_for(employee, vac_day, vac_day).empty?, "#{vac_day} contains no hours")
    end

    # verify days worked
    days_count = 0
    ((period.mid_month + 1) .. period.finish).each do |d|
      next if (d.saturday? || d.sunday?)
      days_count += 1
    end
    assert_equal(days_count, WorkHour.days_worked(employee, period), "now has worked")
  end

  test "Can Enter Vacation Worked" do
    employee = return_valid_employee()
    period = Period.new(2018,1)

    vacation = Vacation.create(
        start_date: '2018-01-15',
        end_date: '2018-01-26',
        employee: employee
    )
    assert(vacation)

    hours = {
      "2018-01-01" => {hours: 8},
      "2018-01-02" => {hours: 8},
      "2018-01-03" => {hours: 8},
      "2018-01-04" => {hours: 8},
      "2018-01-05" => {hours: 8},
      "2018-01-08" => {hours: 8},
      "2018-01-09" => {hours: 8},
      "2018-01-10" => {hours: 8},
      "2018-01-11" => {hours: 8},
      "2018-01-12" => {hours: 8},
      "2018-01-29" => {hours: 8},
      "2018-01-30" => {hours: 8},
      "2018-01-31" => {hours: 8},
      "2018-01-17" => {vacation_worked: 7} # Wednesday # Vacation (Holiday) Hours Worked.
    }

    success, errors = WorkHour.update(employee, hours)
    assert(success, "should have not had errors #{errors.inspect}")

    assert_equal(13, WorkHour.days_worked(employee, period), "should have worked one day")

    exp = {normal: 104.0, vacation_worked: 7.0}
    assert_equal(exp, WorkHour.total_hours(employee, period))

    assert_equal(1, WorkHour.vac_days_worked_in_period(employee, period))
  end

  test "Vacation Worked Validations" do
    employee = return_valid_employee()
    period = Period.new(2018,1)

    vacation = Vacation.create(
        start_date: '2018-01-01',
        end_date: '2018-01-31',
        employee: employee
    )
    assert(vacation)

    hours = {
      "2018-01-17" => {vacation_worked: -1}
    }

    success, errors = WorkHour.update(employee, hours)
    refute(success, "should have been an error")

    hours = {
      "2018-01-17" => {vacation_worked: 28}
    }

    success, errors = WorkHour.update(employee, hours)
    refute(success, "should have been an error")

    hours = {
      "2018-01-17" => {vacation_worked: 18}
    }

    success, errors = WorkHour.update(employee, hours)
    assert(success, "should not have been an error #{errors.inspect}")
  end

  test "only worked holidays" do
    employee = return_valid_employee()
    period = Period.new(2018,5)

    Holiday.create!(name: 'National Day', date: '2018-05-20', observed: '2018-05-21')
    Holiday.create!(name: 'Ascension', date: '2018-05-30')
    Holiday.create!(name: 'Labor Day', date: '2018-05-01')

    vacation = Vacation.create(
        start_date: '2018-05-02',
        end_date: '2018-05-31',
        employee: employee
    )
    assert(vacation)

    assert_equal(3, WorkHour.days_worked(employee, period))
    assert_equal(3, WorkHour.holiday_days_in_period(employee, period))

    assert(WorkHour.only_worked_holidays?(employee, period))

    # Do Vacation Worked
    hours = {
      "2018-05-02" => {vacation_worked: 5}
    }

    success, errors = WorkHour.update(employee, hours)
    assert(success)

    assert_equal(3, WorkHour.days_worked(employee, period))
    assert_equal(1, WorkHour.vac_days_worked_in_period(employee, period))
    assert_equal(3, WorkHour.holiday_days_in_period(employee, period))

    refute(WorkHour.only_worked_holidays?(employee, period))
  end

  test "Vacation Worked Must Happen During Vacation" do
    employee = return_valid_employee()
    period = Period.new(2018,1)

    vacation = Vacation.create(
        start_date: '2018-01-15',
        end_date: '2018-01-26',
        employee: employee
    )
    assert(vacation)

    hours = {
      "2018-01-01" => {hours: 8},
      "2018-01-02" => {hours: 8},
      "2018-01-03" => {hours: 8},
      "2018-01-04" => {hours: 8, vacation_worked: 5},
      "2018-01-05" => {hours: 8},
      "2018-01-08" => {hours: 8},
      "2018-01-09" => {hours: 8},
      "2018-01-10" => {hours: 8},
      "2018-01-11" => {hours: 8},
      "2018-01-12" => {hours: 8},
      "2018-01-29" => {hours: 8},
      "2018-01-30" => {hours: 8},
      "2018-01-31" => {hours: 8},
    }

    success, errors = WorkHour.update(employee, hours)
    refute(success, "should have had errors")
  end

  test "Vacation Worked over 8 hours is Normal Rate (non Overtime)" do
    employee = return_valid_employee()
    period = Period.new(2018,1)

    vacation = Vacation.create(
        start_date: '2018-01-15',
        end_date: '2018-01-26',
        employee: employee
    )
    assert(vacation)

    hours = {
      "2018-01-01" => {hours: 8},
      "2018-01-02" => {hours: 8},
      "2018-01-03" => {hours: 8},
      "2018-01-04" => {hours: 8},
      "2018-01-05" => {hours: 8},
      "2018-01-08" => {hours: 8},
      "2018-01-09" => {hours: 8},
      "2018-01-10" => {hours: 8},
      "2018-01-11" => {hours: 8},
      "2018-01-12" => {hours: 8},
      "2018-01-29" => {hours: 8},
      "2018-01-30" => {hours: 8},
      "2018-01-31" => {hours: 8},
      "2018-01-18" => {vacation_worked: 12} # Thursday
    }

    success, errors = WorkHour.update(employee, hours)
    assert(success, "should have not had errors #{errors.inspect}")

    assert_equal(13, WorkHour.days_worked(employee, period), "should have worked one day")

    exp = {normal: 104.0, vacation_worked: 12.0}
    assert_equal(exp, WorkHour.total_hours(employee, period))
  end

  test "Vacation Worked is always VW even if Overtime" do
    employee = return_valid_employee()
    period = Period.new(2018,1)

    vacation = Vacation.create(
        start_date: '2018-01-15',
        end_date: '2018-01-26',
        employee: employee
    )
    assert(vacation)

    hours = {
      "2018-01-01" => {hours: 8},
      "2018-01-02" => {hours: 8},
      "2018-01-03" => {hours: 8},
      "2018-01-04" => {hours: 8},
      "2018-01-05" => {hours: 8},
      "2018-01-08" => {hours: 8},
      "2018-01-09" => {hours: 8},
      "2018-01-10" => {hours: 8},
      "2018-01-11" => {hours: 8},
      "2018-01-12" => {hours: 8},
      "2018-01-29" => {hours: 8},
      "2018-01-30" => {hours: 8},
      "2018-01-31" => {hours: 8},
      "2018-01-20" => {vacation_worked: 12} # Saturday
    }

    success, errors = WorkHour.update(employee, hours)
    assert(success, "should have not had errors #{errors.inspect}")

    assert_equal(13, WorkHour.days_worked(employee, period), "should have worked one day")

    exp = {normal: 104.0, vacation_worked: 12.0}
    assert_equal(exp, WorkHour.total_hours(employee, period))

    hours = {
      "2018-01-20" => {vacation_worked: 0}, # Saturday
      "2018-01-21" => {vacation_worked: 12} # Sunday
    }

    success, errors = WorkHour.update(employee, hours)
    assert(success, "should have not had errors #{errors.inspect}")

    exp = {normal: 104.0, vacation_worked: 12.0}
    assert_equal(exp, WorkHour.total_hours(employee, period))

    # even working tons of hours during vacation
    # it is always vacation worked time, not overtime
    hours = {
      "2018-01-15" => {vacation_worked: 15},
      "2018-01-16" => {vacation_worked: 15},
      "2018-01-17" => {vacation_worked: 15},
      "2018-01-18" => {vacation_worked: 15},
      "2018-01-19" => {vacation_worked: 15},
      "2018-01-20" => {vacation_worked: 15}, # Saturday
      "2018-01-21" => {vacation_worked: 15}, # Sunday
      "2018-01-22" => {vacation_worked: 15},
      "2018-01-23" => {vacation_worked: 15},
      "2018-01-24" => {vacation_worked: 15},
      "2018-01-25" => {vacation_worked: 15},
      "2018-01-26" => {vacation_worked: 15}
    }

    success, errors = WorkHour.update(employee, hours)
    assert(success, "should have not had errors #{errors.inspect}")


    exp = {normal: 104.0, vacation_worked: 180.0}
    assert_equal(exp, WorkHour.total_hours(employee, period))

    # Add a holiday on 2018-01-22
    # That should make the time is holiday OT even though there's
    # And active vacation over that period.
    Holiday.create!(name: 'The Ides of January', date: '2018-01-15')

    success, errors = WorkHour.update(employee, hours)
    assert(success, "should have not had errors #{errors.inspect}")

    exp = {normal: 104.0, vacation_worked: 165.0, holiday: 15.0}
    assert_equal(exp, WorkHour.total_hours(employee, period))
  end

  def some_valid_params
    {employee: @luke, date: '2017-08-09', hours: 9}
  end
end
