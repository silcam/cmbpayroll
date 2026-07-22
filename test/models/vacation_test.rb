require "test_helper"

class VacationTest < ActiveSupport::TestCase
  def setup
    Payslip.reset_column_information

    @luke = employees :Luke
    @anakin = employees :Anakin
    @lukes_vacation = vacations :LukeInKribi
    @lukes_overtime = work_hours :LukesOvertime
  end

  test "Check presence of required attributes (which is all of them)" do
    params = some_valid_params
    model_validation_hack_test Vacation, params
  end

  test "Start date not a date" do
    params = some_valid_params start_date: 'abc'
    refute Vacation.new(params).valid?
  end

  test "Start date not valid" do
    params = some_valid_params start_date: '2017-02-31'
    refute Vacation.new(params).valid?
  end

  test "End date not a date" do
    params = some_valid_params end_date: 'abc'
    refute Vacation.new(params).valid?
  end

  test "End Date before start date fails validation" do
    params = some_valid_params end_date: '2017-09-08'
    refute Vacation.new(params).valid?
  end

  test "End date and start date the same ok" do
    params = some_valid_params
    params[:end_date] = params[:start_date]
    assert Vacation.new(params).valid?
  end

  test "Vacation can compute the number of days" do
    params = { employee: @luke, start_date: '2017-09-13', end_date: '2017-09-14' }

    vacation = Vacation.new(params)
    assert(vacation.valid?, "new vacation should be valid")
    assert_equal(2, vacation.days, "This vacation should be 2 days")

    params = { employee: @luke, start_date: '2017-09-13', end_date: '2017-09-13' }
    vacation = Vacation.new(params)
    assert(vacation.valid?, "new vacation should be valid")
    assert_equal(1, vacation.days,
        "Vacation that starts and ends the same day should be 1 day")

    params = { employee: @luke, start_date: '2017-09-04', end_date: '2017-09-27' }
    vacation = Vacation.new(params)
    assert(vacation.valid?, "new vacation should be valid")
    assert_equal(18, vacation.days, "18 days -- should not count weekends")
    assert_equal(Date.new(2017,9,4), vacation.start_date, "should not have adjusted start date")
    assert_equal(Date.new(2017,9,27), vacation.end_date, "should not have adjusted end date")

    params = { employee: @luke, start_date: '2018-01-28', end_date: '2018-02-18' }
    vacation = Vacation.new(params)
    assert(vacation.valid?, "new vacation should be valid")
    assert_equal(15, vacation.days, "15 days -- should not count weekends")

    holiday = Holiday.new(name: "National Day", date: '2018-02-01')
    assert(holiday.valid?, "holiday is valid")
    holiday.save
    assert_equal(14, vacation.days, "14 days -- should not count the holiday I just added")
  end

  test "Vacations can't overlap existing" do
    invalids = [{employee: @luke, start_date: '2017-09-14', end_date: '2017-09-15'},
                {employee: @luke, start_date: '2017-09-15', end_date: '2017-09-15'},
                {employee: @luke, start_date: '2017-09-16', end_date: '2017-09-17'},
                {employee: @luke, start_date: '2017-09-17', end_date: '2017-09-23'},
                {employee: @luke, start_date: '2017-09-14', end_date: '2017-09-20'}]
    invalids.each { |p| assert Vacation.new(p).valid? }
    @luke.vacations.create!(start_date: '2017-09-15', end_date: '2017-09-19')
    invalids.each do |params|
      refute Vacation.new(params).valid?, "Vacation from #{params[:start_date]} to #{params[:end_date]} overlaps"
    end
  end

  test "Vacation can obviously overlap itself" do
    LastPostedPeriod.unpost # Reopen July so we can edit
    assert @lukes_vacation.update end_date: '2017-07-30'
  end

  test "Overlapped work hours get clobbered" do
    lukes_day_off = @luke.work_hours.find_by(date: '2017-08-08')
    assert(lukes_day_off, "should exist")

    @vacation = Vacation.new(employee_id: @luke.id, start_date: '2017-08-08', end_date: '2017-08-08')
    @vacation.save!

    assert_nil WorkHour.find_by id: lukes_day_off.id
    lukes_day_off = @luke.work_hours.find_by(date: '2017-08-08')
    assert_nil(lukes_day_off)
  end

  test "No Overlapped Work Hours" do
    v = Vacation.new(some_valid_params)
    assert_empty v.overlapped_work_hours
    refute v.overlaps_work_hours?
  end

  # test "Overlaps overtime at start date" do
  #   v = Vacation.new some_valid_params(start_date: @lukes_overtime.date)
  #   assert_includes v.overlapped_work_hours, @lukes_overtime
  #   assert v.overlaps_work_hours?
  # end
  #
  # test "Overlaps overtime at end date" do
  #   v = Vacation.new some_valid_params(start_date: '2017-08-01', end_date: @lukes_overtime.date)
  #   assert_includes v.overlapped_work_hours, @lukes_overtime
  # end
  #
  # test "Overlaps overtime in the middle" do
  #   v = Vacation.new some_valid_params( start_date: '2017-08-01')
  #   assert_includes v.overlapped_work_hours, @lukes_overtime
  # end
  #
  # test "overlaps_work_hours? ignores 0hr days" do
  #   WorkHour.create!(employee: @luke, date: '2017-08-09', hours: 0)
  #   v = Vacation.new some_valid_params
  #   refute v.overlaps_work_hours?, "Should ignore overlap with the day off"
  # end

  test "Can't delete old vacations" do
    refute @lukes_vacation.destroy
    assert_raises(Exception){ @lukes_vacation.destroy! }

    v = end_of_aug_vacay
    v.save!
    assert v.destroyable?
    LastPostedPeriod.post_current
    refute v.destroyable?
    assert_raises(Exception){ v.destroy! }
  end

  test "Can delete future vacations just fine" do
    future_vacay = Vacation.create(employee: @luke, start_date: '2027-09-05', end_date: '2027-09-05')
    future_vacay.destroy
    assert_nil Vacation.find_by(id: future_vacay.id), "The failure of this test is a friendly reminder that the codebase is now over 10 years old :)"
  end

  test "Can't create vacations in posted period" do
    LastPostedPeriod.post_current
    refute end_of_aug_vacay.save
    LastPostedPeriod.unpost
    assert end_of_aug_vacay.save
  end

  test "Editing vacations and the Posted Period and You" do
    v = end_of_aug_vacay
    v.save!
    LastPostedPeriod.post_current
    v.end_date = '2017-09-30'
    assert v.save
    v.start_date = '2017-08-30'
    refute v.save

    v.reload
    v.start_date = '2017-09-01'
    refute v.save

    v.reload
    v.end_date = '2017-08-31'
    refute v.save

    v.reload
    LastPostedPeriod.post_current
    v.end_date = '2017-09-29'
    refute v.save
  end

  test "Period Vacations" do
    on_sep_5 do
      chewie = employees :Chewie
      chewie1 = Vacation.create(employee: chewie, start_date: '2017-11-15', end_date: '2017-12-01')
      chewie2 = Vacation.create(employee: chewie, start_date: '2017-12-30', end_date: '2018-01-15')
      dec_vacays = Vacation.for_period(Period.new(2017, 12))
      assert_includes dec_vacays, chewie1
      assert_includes dec_vacays, chewie2
      refute_includes Vacation.for_period, @lukes_vacation
    end
  end

  test "Upcoming Vacations" do
    Date.stub :today, Date.new(2017, 6, 30) do
      assert_includes Vacation.upcoming_vacations, @lukes_vacation
    end
    Date.stub :today, Date.new(2017,7,1) do
      refute_includes Vacation.upcoming_vacations, @lukes_vacation
    end
  end

  test "First Supplemental Accrual Period" do
    employee = return_valid_employee()

    employee.first_day = employee.contract_start = "2018-09-12"
    assert_equal(Period.new(2022,10), Vacation.first_supplemental_accrual_period(employee))

    employee.first_day = employee.contract_start = "2012-03-12"
    assert_equal(Period.new(2016,4), Vacation.first_supplemental_accrual_period(employee))
  end

  test "period_supplemental_days cannot be less than zero" do
    employee = return_valid_employee()
    employee.contract_start = "2018-08-01"
    employee.first_day = "2018-08-01"

    assert_equal(0, Vacation.period_supplemental_days(employee, Period.new(2013, 1)))
  end

  test "earned supplemental days soon after contract_start" do
    employee = return_valid_employee()
    employee.contract_start = "2012-08-01"
    employee.first_day = "2012-08-01"

    assert_equal(0, Vacation.period_supplemental_days(employee, Period.new(2013, 1)))
  end

  test "Number of Supplemental Days Earned is correct" do
    @luke.contract_start = "2012-08-01"
    @luke.first_day = "2012-08-01"

    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2013, 1)))

    earned_days = 1.5 + ((2/12.0) * 1)
    assert_equal(earned_days, Vacation.days_earned(@luke, Period.new(2017, 1)))

    # Anniversaries aren't special at all, normal months like everything else.
    earned_days = 1.5 + ((2/12.0) * 1)
    assert_equal(earned_days.round(3), Vacation.days_earned(@luke, Period.new(2017, 8)).round(3))

    Vacation.create!(start_date: "2017-12-05", end_date: "2017-12-06", employee: @luke)

    # month-by-month accrual is correct
    assert_equal(0, Vacation.period_supplemental_days(@luke, Period.new(2016,12)))
    assert_equal(2/12.0, Vacation.period_supplemental_days(@luke, Period.new(2017,1)))
    assert_equal(2/12.0, Vacation.period_supplemental_days(@luke, Period.new(2017,2)))
    assert_equal(2/12.0, Vacation.period_supplemental_days(@luke, Period.new(2017,3)))
    assert_equal(2/12.0, Vacation.period_supplemental_days(@luke, Period.new(2017,9)))
    assert_equal(2/12.0, Vacation.period_supplemental_days(@luke, Period.new(2017,10)))
    assert_equal(2/12.0, Vacation.period_supplemental_days(@luke, Period.new(2017,11)))
    assert_equal(2/12.0, Vacation.period_supplemental_days(@luke, Period.new(2017,12)))

    # one period at a time is given out by suppl days.
    assert_equal(earned_days, Vacation.days_earned(@luke, Period.new(2017, 12)))
  end

  test "Period suppl days" do
    employee = return_valid_employee()
    employee.contract_start = "2009-10-01"
    employee.first_day = "1986-05-06"

    assert_equal(0, Vacation.period_supplemental_days(employee, Period.new(2013,12)))
    assert_equal(0.167, Vacation.period_supplemental_days(employee, Period.new(2014,1)).round(3))
    assert_equal(0.167, Vacation.period_supplemental_days(employee, Period.new(2014,2)).round(3))
    assert_equal(0.167, Vacation.period_supplemental_days(employee, Period.new(2015,1)).round(3))
  end

  # THIS ISN'T A REAL TEST (FIXME)
  test "Period Supplemental Days Each Period" do
    employee = return_valid_employee()
    employee.contract_start = "2013-08-01"
    employee.first_day = "2013-08-01"

    start = Period.new(2013,1)
    finish = Period.new(2023,10)

    (start .. finish).each do |p|
      #Rails.logger.error(" #{p} gets us: #{Vacation.period_supplemental_days(employee, p)}")
    end
  end

  test "Supplemental Days Are Earned Each Month With Normal Days" do
    # @luke contract_start: 2017-01-01
    @luke.first_day = "2017-01-01"
    @luke.save

    # Before hire, no days earned.
    assert_equal(0, Vacation.days_earned(@luke, Period.new(2016, 12)))

    # Normal months
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2017, 1)))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2021, 1)))

    assert_equal((2/12.0) * 1, Vacation.period_supplemental_days(@luke, Period.new(2022, 1)))

    # First month of extra supplemental days
    earned_days = 1.5 + (2/12.0) * 1

    assert_equal(earned_days.round(3), Vacation.days_earned(@luke, Period.new(2022, 1)).round(3))
    assert_equal(earned_days.round(3), Vacation.days_earned(@luke, Period.new(2022, 2)).round(3))
    Vacation.create!(start_date: "2022-03-03", end_date: "2022-03-04", employee: @luke)
    assert_equal(earned_days.round(3), Vacation.days_earned(@luke, Period.new(2022, 3)).round(3))
    assert_equal(earned_days.round(3), Vacation.days_earned(@luke, Period.new(2022, 4)).round(3))
  end

  test "Starts In" do
    Vacation.all.delete_all
    assert_equal(0, Vacation.all.size, "shouldn't be any")

    vac = Vacation.create!(start_date: "2018-11-03", end_date: "2018-12-03", employee: @luke)
    assert_equal(0, Vacation.starts_in(@luke, Period.new(2018,10)).size)
    assert_equal(1, Vacation.starts_in(@luke, Period.new(2018,11)).size)
    assert_equal(0, Vacation.starts_in(@luke, Period.new(2018,12)).size)

    vac = Vacation.create!(start_date: "2018-11-02", end_date: "2018-11-02", employee: @luke)
    assert_equal(0, Vacation.starts_in(@luke, Period.new(2018,10)).size)
    assert_equal(2, Vacation.starts_in(@luke, Period.new(2018,11)).size)
    assert_equal(0, Vacation.starts_in(@luke, Period.new(2018,12)).size)

    vac = Vacation.create!(start_date: "2018-11-01", end_date: "2018-11-01", employee: @luke)
    assert_equal(0, Vacation.starts_in(@luke, Period.new(2018,10)).size)
    assert_equal(3, Vacation.starts_in(@luke, Period.new(2018,11)).size)
    assert_equal(0, Vacation.starts_in(@luke, Period.new(2018,12)).size)

    vac = Vacation.create!(start_date: "2018-10-02", end_date: "2018-10-11", employee: @anakin)
    vac = Vacation.create!(start_date: "2018-12-31", end_date: "2018-12-31", employee: @luke)
    assert_equal(0, Vacation.starts_in(@luke, Period.new(2018,10)).size)
    assert_equal(3, Vacation.starts_in(@luke, Period.new(2018,11)).size)
    assert_equal(1, Vacation.starts_in(@luke, Period.new(2018,12)).size)
  end

  test "Days Used" do
    # Before hire
    assert_equal 0, Vacation.days_used(@luke, Period.new(2016, 11))

    # Normal Month
    assert_equal 0, Vacation.days_used(@luke, Period.new(2017, 6))

    # Took off all of July
    assert_equal 21, Vacation.days_used(@luke, Period.new(2017, 7))

    # Doesn't count Holidays
    @luke.vacations << Vacation.new(start_date: '2017-12-25', end_date: '2017-12-26')
    assert_equal 1, Vacation.days_used(@luke, Period.new(2017, 12))
  end

  test "Vacation Balance" do
    # From before first payslip
    assert_equal 0, Vacation.balance(@luke, Period.new(2016, 11))

    # From Posted Payslip
    assert_equal 4, Vacation.balance(@luke, Period.new(2017, 7))

    # For following periods
    assert_equal 5.5, Vacation.balance(@luke, Period.new(2017, 8))
    assert_equal 7, Vacation.balance(@luke, Period.new(2017, 9))
    @luke.vacations << Vacation.new(start_date: '2017-09-04', end_date: '2017-09-08')
    assert_equal 2, Vacation.balance(@luke, Period.new(2017, 9))

    # For new employees
    chewie = employees :Chewie # Started 4 Aug
    assert_equal 1.5, Vacation.balance(chewie, Period.new(2017, 8))
    chewie.vacations << Vacation.new(start_date: '2017-08-07', end_date: '2017-08-11')
    assert_equal -3.5, Vacation.balance(chewie, Period.new(2017, 8))
  end

  test "Luke is on vacation all of July" do
    assert Vacation.on_vacation_during(@luke, Date.new(2017, 7, 1), Date.new(2017, 7, 31))
    assert Vacation.on_vacation_during(@luke, Date.new(2017, 7, 10), Date.new(2017, 7, 25))
  end

  test "Anakin is not on vacation all of June" do
    refute Vacation.on_vacation_during(@anakin, Date.new(2017, 6, 1), Date.new(2017, 6, 9))
    refute Vacation.on_vacation_during(@anakin, Date.new(2017, 6, 5), Date.new(2017, 6, 10))
  end

  test "More vacation for Luke" do
    @luke.vacations.create(start_date: '2017-12-25', end_date: '2018-01-20')
    @luke.vacations.create(start_date: '2018-01-21', end_date: '2018-02-04')
    assert Vacation.on_vacation_during(@luke, Date.new(2018, 1, 1), Date.new(2018, 1, 31))
  end

  test "Days Hash" do
    days = Vacation.days_hash(@luke, Date.new(2017, 7, 30), Date.new(2017, 8, 2))
    assert_equal 2, days.length
    assert days[Date.new(2017, 7, 31)][:vacation]
  end

  test "Vacations Can be paid" do
    vacay = Vacation.create()
    vacay.employee = @luke
    vacay.start_date = "2018-01-01"
    vacay.end_date = "2018-12-31"
    refute(vacay.paid?, "should not be paid by default")

    assert(vacay.valid?, "should be valid")
    assert(vacay.save, "should save correctly")

    vacay.paid = true
    assert(vacay.paid?, "should be paid now")
  end

  test "Vacation knows how much should be paid for vacations" do
    period = Period.from_date(@lukes_vacation.start_date)
    payslip = @luke.payslip_for(period)
    assert(payslip, "payslip exists")

    # Adjust this so this test can run.
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: 2017, month: 1
    lpp.save!

    # make payslip valid.
    payslip.net_pay = 342345
    create_earnings(payslip)

    original_days_balance = 32.0
    original_pay_balance = 286978
    set_previous_vacation_balances(@luke, period, original_pay_balance, original_days_balance)

    # Set up balances.
    payslip.vacation_balance = original_days_balance
    payslip.vacation_pay_balance = original_pay_balance
    assert(payslip.save, "should save properly")

    payslip = Payslip.process(@luke, period)
    assert(payslip.on_vacation_entire_period?, "on vaca in Kribi")

    # Vacation pay is computed by vacation_daily_rate * days
    daily_rate = payslip.vacation_daily_rate
    # TODO how is this computed?
    assert_equal(4288.125, daily_rate, "daily rate is correct")

    days = @lukes_vacation.days
    assert_equal(21, days, "luke 21 days off to go to Kribi")

    exp = (days * daily_rate).round
    assert_equal(exp, @lukes_vacation.vacation_pay, "vacation pay is correct for vacation")

    # original balance + no accrual because on vacation whole period.
    new_days_bal = original_days_balance + 0.0 - 21
    assert_equal(new_days_bal, payslip.vacation_balance)

    # NB. Vacation pay balance is just what would be paid out if the employee
    #     Took all their vacation at once. It is not a running balance from a
    #     total just a indication of the liability each employee has in their
    #     vacation total. It is recomputed each month from scratch.
    assert_equal((new_days_bal * daily_rate).round, payslip.vacation_pay_balance)
  end

  test "vacation_pay does not change once marked paid, even if later payslips differ" do
    employee = return_valid_employee
    employee.contract_start = Date.new(2010, 1, 1)
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"
    employee.save

    period = Period.new(2018, 1)
    set_previous_vacation_balances(employee, period, 100000, 20.0)

    vacation = Vacation.create!(employee: employee,
        start_date: '2018-01-10', end_date: '2018-01-14')
    generate_work_hours_for_range(employee, period.start, Date.new(2018, 1, 9))

    may_payslip = Payslip.process(employee, period)
    original_rate = may_payslip.vacation_daily_rate

    vacation.mark_paid
    assert(vacation.save, "should save properly")

    original_pay = vacation.vacation_pay
    assert(original_pay > 0, "vacation pay should have been computed")

    # Something changes that affects a LATER payslip's compute_fullcnpswage
    # (e.g. a bonus assignment), analogous to whatever shifted Pascaline's
    # July payslip relative to her May one.
    bonus = Bonus.create!(name: "Test Bonus", bonus_type: "fixed", quantity: 50000)
    employee.bonuses << bonus

    later_period = Period.new(2018, 2)
    generate_work_hours(employee, later_period)
    Payslip.process(employee, later_period)

    # Confirm the later payslip really did diverge -- otherwise this test
    # would pass trivially.
    refute_equal(original_rate, Vacation.vacation_daily_rate(employee),
        "the later payslip's daily rate should genuinely differ, to make this a real test")

    # The May payslip itself -- the one the voucher must select -- must also
    # report a stable rate after later payslips are processed. Selecting the
    # right payslip isn't enough if that payslip's own rate isn't pinned.
    assert_equal(original_rate, Payslip.for_employee_for_period(employee, period).vacation_daily_rate,
        "the May payslip's own vacation_daily_rate must stay pinned to when it was processed")

    # And the paid vacation's total must not have moved either.
    assert_equal(original_pay, vacation.vacation_pay,
        "a paid vacation's pay must not drift after later payslips are processed")
    assert_equal(original_pay, vacation.reload.vacation_pay,
        "the persisted vacation_pay must also reflect the original, paid figure")
  end

  test "vacation_pay locks once the start date has passed, even if never marked paid" do
    employee = return_valid_employee
    employee.contract_start = Date.new(2010, 1, 1)
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"
    employee.save

    period = Period.new(2018, 1)
    set_previous_vacation_balances(employee, period, 100000, 20.0)

    vacation = Vacation.create!(employee: employee,
        start_date: '2018-01-10', end_date: '2018-01-14')
    generate_work_hours_for_range(employee, period.start, Date.new(2018, 1, 9))

    Payslip.process(employee, period)

    # Nobody marked this paid -- but its start date (2018-01-10) is long
    # past today, so the first computation should still lock it.
    refute(vacation.paid?, "not marked paid")
    original_pay = vacation.vacation_pay
    assert(original_pay > 0, "vacation pay should have been computed")

    bonus = Bonus.create!(name: "Test Bonus", bonus_type: "fixed", quantity: 50000)
    employee.bonuses << bonus

    later_period = Period.new(2018, 2)
    generate_work_hours(employee, later_period)
    Payslip.process(employee, later_period)

    refute_equal(original_pay.fdiv(vacation.days), Vacation.vacation_daily_rate(employee),
        "the later payslip's daily rate should genuinely differ, to make this a real test")

    assert_equal(original_pay, vacation.vacation_pay,
        "an unpaid but already-started vacation's pay must still not drift " +
          "-- this is the backstop for a forgotten paid marking")
    refute(vacation.paid?, "still not explicitly marked paid")
  end

  test "vacation_pay still recomputes for a future, unpaid vacation (not prematurely locked)" do
    employee = return_valid_employee
    employee.contract_start = Date.new(2010, 1, 1)
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"
    employee.save

    period = Period.new(2018, 1)
    set_previous_vacation_balances(employee, period, 100000, 20.0)

    future_start = Date.today + 30
    future_end = future_start + 3
    vacation = Vacation.create!(employee: employee,
        start_date: future_start, end_date: future_end)
    generate_work_hours_for_range(employee, period.start, Date.new(2018, 1, 9))

    Payslip.process(employee, period)

    refute(vacation.paid?, "not marked paid")
    refute(vacation.start_date <= Date.today, "start date should be in the future")
    original_pay = vacation.vacation_pay
    assert(original_pay > 0, "should have computed a real value")

    # Change an input and process a new (now most-recent) payslip. Since this
    # vacation is neither paid nor started, it must NOT be locked -- if a
    # future refactor caused it to lock prematurely, this would incorrectly
    # stay equal to original_pay.
    bonus = Bonus.create!(name: "Test Bonus", bonus_type: "fixed", quantity: 50000)
    employee.bonuses << bonus
    later_period = Period.new(2018, 2)
    generate_work_hours(employee, later_period)
    Payslip.process(employee, later_period)

    refute_equal(original_pay, vacation.vacation_pay,
        "an unpaid, not-yet-started vacation must keep recomputing against " +
          "the current most-recent payslip, not lock prematurely")
  end

  test "voucher for a vacation spanning two months shows the rate pinned to its own period, not a later reprocessed one" do
    employee = return_valid_employee
    employee.contract_start = Date.new(2010, 1, 1)
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"
    employee.save

    # Mirrors the reported case: a vacation crossing a month boundary, with
    # more days falling in the first (January) month than the second
    # (February) -- apply_to_period should therefore resolve to January.
    period = Period.new(2018, 1)
    set_previous_vacation_balances(employee, period, 100000, 20.0)

    vacation = Vacation.create!(employee: employee,
        start_date: '2018-01-21', end_date: '2018-02-05')
    assert_equal(period, vacation.apply_to_period,
        "more days fall in January, so the voucher should be keyed to January")

    generate_work_hours_for_range(employee, period.start, Date.new(2018, 1, 20))

    Payslip.process(employee, period)
    vacation.mark_paid
    assert(vacation.save, "should save properly")

    original_rate = Payslip.for_employee_for_period(employee, vacation.apply_to_period).vacation_daily_rate

    # Something changes an employee input, then February and March are
    # processed -- as would happen by the time a January voucher is
    # reprinted/viewed months later.
    bonus = Bonus.create!(name: "Test Bonus", bonus_type: "fixed", quantity: 50000)
    employee.bonuses << bonus

    generate_work_hours_for_range(employee, Date.new(2018, 2, 6), Period.new(2018, 2).finish)
    Payslip.process(employee, Period.new(2018, 2))

    generate_work_hours(employee, Period.new(2018, 3))
    Payslip.process(employee, Period.new(2018, 3))

    refute_equal(original_rate, Vacation.vacation_daily_rate(employee),
        "most_recent should now point to a later, genuinely different payslip")

    voucher = VoucherPdf.new(vacation)
    voucher_payslip = voucher.instance_variable_get(:@payslip)

    assert_equal(Payslip.for_employee_for_period(employee, vacation.apply_to_period).id, voucher_payslip.id,
        "the voucher must select the vacation's own (January) payslip")
    assert_equal(original_rate, voucher_payslip.vacation_daily_rate,
        "the voucher's payslip must report the rate pinned to when it was processed")
  end

  test "Vacation (payslip) can figure how much taxes are for this vacation" do
    period = Period.from_date(@lukes_vacation.start_date)
    payslip = @luke.payslip_for(period)
    assert(payslip, "payslip exists")

    # Adjust this so this test can run.
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: 2017, month: 1
    lpp.save!

    # make payslip valid.
    payslip.net_pay = 342345
    create_earnings(payslip)
    set_previous_vacation_balances(@luke, period, 286978, 42.0)

    payslip = Payslip.process(@luke, period)

    # Set up balances.
    payslip.vacation_balance = 42.0
    payslip.vacation_pay_balance = 286978
    assert(payslip.save, "should save properly")

    # Do the test.
    assert_equal(21, @lukes_vacation.days, "luke 21 days off to go to Kribi")

    exp_rate = (payslip.compute_fullcnpswage) * 12 / 16.0 / 18.0
    assert_equal(exp_rate, payslip.vacation_daily_rate, "can compute vacation rate")

    exp_pay = ( exp_rate * @lukes_vacation.days ).round

    assert_equal(exp_pay, @lukes_vacation.vacation_pay,
        "luke gets his vacation daily rate for each of the 21 " +
          "days off he went to Kribi")
    tax = Tax.compute_taxes(@luke, @lukes_vacation.vacation_pay, @lukes_vacation.vacation_pay)

    assert_equal(tax.ccf, @lukes_vacation.get_tax.ccf)
    assert_equal(tax.crtv, @lukes_vacation.get_tax.crtv)
    assert_equal(tax.proportional, @lukes_vacation.get_tax.proportional)
    assert_equal(tax.cac, @lukes_vacation.get_tax.cac)
    assert_equal(tax.cac2, @lukes_vacation.get_tax.cac2)
    assert_equal(tax.communal, @lukes_vacation.get_tax.communal)
    assert_equal(tax.cnps, @lukes_vacation.get_tax.cnps)
    assert_equal(tax.total_tax, @lukes_vacation.get_tax.total_tax)
  end

  test "Cannot edit vacations that are paid" do
    period = LastPostedPeriod.current

    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = period.start
    vac.end_date = period.finish
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.editable?)

    vac.paid = true
    assert(vac.save)

    refute(vac.editable?)

    vac.end_date = vac.end_date - 1
    refute(vac.save, "cannot edit a paid vacation")
  end

  test "Cannot delete vacations that are paid" do
    period = LastPostedPeriod.current

    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = period.start
    vac.end_date = period.finish
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)

    vac.paid = true

    refute(vac.destroyable?)
    refute(vac.destroy, "cannot delete a paid vacation")
  end

  test "Month with Most Days Off, Single Month" do
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-12"
    vac.end_date = "2018-09-14"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")

    assert_equal(Period.new(2018,9), vac.apply_to_period())
  end

  test "Month with Most Days Off, Two Months" do
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-22"
    vac.end_date = "2018-10-31"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")

    assert_equal(Period.new(2018,10), vac.apply_to_period())
  end

  test "Month with Most Days Off, Three Months" do
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-22"
    vac.end_date = "2018-11-02"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")

    assert_equal(Period.new(2018,10), vac.apply_to_period())
  end

  test "Data is Stored in DB" do
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-22"
    vac.end_date = "2018-11-02"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")

    assert_equal(Period.new(2018,10), vac.apply_to_period())

    # force the items to get in the DB
    vac.prep_print

    assert_equal(10, vac.period_month, "correct month")
    assert_equal(2018, vac.period_year, "correct year")
  end

  test "Tax is Stored in DB" do
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-01"
    vac.end_date = "2018-09-21"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")

    period = Period.from_date(vac.start_date)

    hours = {
      "2018-09-24" => {hours: 8},
      "2018-09-25" => {hours: 8},
      "2018-09-26" => {hours: 8},
      "2018-09-27" => {hours: 8},
      "2018-09-28" => {hours: 8}
    }

    success, errors = WorkHour.update(@luke, hours)
    assert(success, "should not have produced these errors: #{errors.inspect}")

    #payslip = Payslip.process(@luke, period)

    set_previous_vacation_balances(@luke, period, 286978, 42.0)
    payslip = Payslip.process(@luke, period)
    assert(payslip, "payslip exists")

    # Set up balances.
    payslip.vacation_balance = 42.0
    payslip.vacation_pay_balance = 286978
    assert(payslip.save, "should save properly")

    # Do the test.
    assert_equal(15, vac.days, "luke 5 days off to go to Kribi")

    # force the items to get in the DB
    vac.prep_print

    #exp_rate = (payslip.compute_fullcnpswage + @luke.transportation) * 12 / 16.0 / 18.0
    exp_rate = (payslip.compute_fullcnpswage) * 12 / 16.0 / 18.0
    assert(exp_rate > 0, "should not be zero")
    assert_equal(exp_rate, payslip.vacation_daily_rate, "can compute vacation rate")

    tot_pay = (exp_rate * vac.days).round
    assert_equal(tot_pay, vac.vacation_pay, "correct vac_pay")
    assert_equal(65608.00, vac.vacation_pay.round(2), "correct absolute val")

    tax_obj = vac.get_tax
    # verify all tax components are stored.
    assert_equal(vac.ccf, tax_obj.ccf)
    assert_equal(vac.crtv, tax_obj.crtv)
    assert_equal(vac.proportional, tax_obj.proportional)
    # From the table
    assert_equal(358, tax_obj.proportional)
    assert_equal(vac.cac, tax_obj.cac)
    assert_equal(vac.cac2, tax_obj.cac2)
    assert_equal(vac.communal, tax_obj.communal)
    assert_equal(vac.cnps, tax_obj.cnps)
    assert_equal(vac.total_tax, tax_obj.total_tax)
    assert_equal(4805, vac.total_tax, "correct tax")
  end

  test "Days in Period" do
    aug = Period.new(2018,8)
    sept = Period.new(2018,9)
    oct = Period.new(2018,10)

    # Days
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-12"
    vac.end_date = "2018-09-14"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)

    assert_equal(0, vac.days_in_period(aug))
    assert_equal(3, vac.days_in_period(sept))
    assert_equal(0, vac.days_in_period(oct))
  end

  test "Days in Period with Holiday" do
    aug = Period.new(2018,8)
    sept = Period.new(2018,9)
    oct = Period.new(2018,10)

    holiday = Holiday.new
    holiday.name = "September Day"
    holiday.date = "2018-09-13"
    assert(holiday.save)

    # Days
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-12"
    vac.end_date = "2018-09-14"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)

    assert_equal(0, vac.days_in_period(aug))
    assert_equal(2, vac.days_in_period(sept))
    assert_equal(0, vac.days_in_period(oct))
  end

  test "Days in Period with Vacation Spanning into Month" do
    aug = Period.new(2018,8)
    sept = Period.new(2018,9)
    oct = Period.new(2018,10)

    # Days
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-08-29"
    vac.end_date = "2018-09-14"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)

    assert_equal(3, vac.days_in_period(aug))
    assert_equal(10, vac.days_in_period(sept))
    assert_equal(0, vac.days_in_period(oct))
  end

  test "Days in Period with Vacation Spanning out of Month" do
    aug = Period.new(2018,8)
    sept = Period.new(2018,9)
    oct = Period.new(2018,10)

    # Days
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-21"
    vac.end_date = "2018-10-08"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)

    assert_equal(0, vac.days_in_period(aug))
    assert_equal(6, vac.days_in_period(sept))
    assert_equal(6, vac.days_in_period(oct))
  end

  test "Days in Period with Vacation Spanning across Month" do
    aug = Period.new(2018,8)
    sept = Period.new(2018,9)
    oct = Period.new(2018,10)

    # Days
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-08-21"
    vac.end_date = "2018-10-08"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)

    assert_equal(9, vac.days_in_period(aug))
    assert_equal(20, vac.days_in_period(sept))
    assert_equal(6, vac.days_in_period(oct))
  end

  test "Can find out days used and pay earned per month" do
    sept = Period.new(2018,9)
    oct = Period.new(2018,10)

    # Need to have a payslip in the start_date Period
    sept_ps = @luke.payslip_for(sept)
    sept_ps = create_and_return_payslip(@luke, sept) if (sept_ps.nil?)

    sept_ps.vacation_balance = 25
    sept_ps.vacation_pay_balance = 152423

    assert_equal(5000, @luke.transportation)
    # This is the vacation calculation
    #exp = (sept_ps.compute_fullcnpswage + @luke.transportation) * 12 / 16.0 / 18.0
    exp = (sept_ps.compute_fullcnpswage) * 12 / 16.0 / 18.0

    assert_equal(exp, sept_ps.vacation_daily_rate)
    assert(sept_ps.valid?)
    assert(sept_ps.save)

    # Create and init vacation
    vac = Vacation.new
    vac.employee = @luke
    vac.start_date = "2018-09-12"
    vac.end_date = "2018-10-15"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)
    vac.paid = true

    # Count Vac Days/Pay for September
    assert_equal(13, vac.days_in_period(sept), "correct number of days in September counted")
    assert_equal((exp * 13).round, vac.pay_per_period(sept), "correct vacation pay for September")

    # Count Vac Days/Pay for October
    assert_equal(11, vac.days_in_period(oct), "correct number of days in October counted")
    assert_equal((exp * 11).round, vac.pay_per_period(oct), "correct vacation pay for October")
  end

  test "Cannot pay vacation in a closed period" do
    # Create vacation pay, normally
    employee = return_valid_employee()
    employee.first_day = '2020-01-01'
    employee.contract_start = '2020-01-01'
    employee.save
    period = Period.new(2020, 3)

    mar_wage = employee.wage

    prev_vac_pay_bal = 78353
    prev_vac_bal = 15.5
    generate_work_hours(employee, period.previous)
    set_previous_vacation_balances(employee, period, prev_vac_pay_bal, prev_vac_bal)

    prev_payslip = Payslip.for_employee_for_period(employee, period.previous)
    assert_equal(prev_vac_bal, prev_payslip.vacation_balance)

    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)
    assert_equal(prev_vac_bal + 1.5, payslip.vacation_balance) # 1.5 should be added from prev.

    assert_equal(1.5, Vacation.days_earned(employee, period))
    assert_equal(1.5, payslip.vacation_earned())

    # Make a vacation for this period.
    vac = Vacation.new(start_date: "2020-03-03", end_date: "2020-03-23")
    employee.vacations << vac
    assert_equal(period, vac.apply_to_period())

    mar_emp_vac_pay = vac.vacation_pay
    assert(mar_emp_vac_pay > 0, "pay is non-zero")

    # Advance period
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: 2020, month: 3 # make 2020-03 posted
    lpp.save!
    april_period = Period.new(2020, 4)

    # Give raise
    employee.category_four!
    employee.echelon_a!
    employee.save
    apr_wage = employee.wage
    assert(apr_wage > mar_wage, "pay has increased")

    generate_work_hours(employee, april_period)
    payslip = Payslip.process(employee, april_period)

    # Verify nothing changes
    apr_emp_vac_pay = vac.vacation_pay
    assert_equal(mar_emp_vac_pay,apr_emp_vac_pay, "pay did not change, despite raise")
  end

  test "Mark paid makes paid" do
    refute(@lukes_vacation.paid?, "not paid yet")
    assert_equal(0, @lukes_vacation.changes.size, "nothing to be saved to the DB")

    # Adjust this so this test can run, since it needs
    # to be in a period that has not been posted.
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: 2017, month: 6 # before July 2017
    lpp.save!

    @lukes_vacation.prep_print
    assert(@lukes_vacation.vacation_pay, "has vacation pay")
    refute(@lukes_vacation.paid?, "paid now")

    @lukes_vacation.mark_paid
    assert(@lukes_vacation.vacation_pay, "has vacation pay")
    assert(@lukes_vacation.paid?, "paid now")
  end

  test "printing makes paid and saves vacation pay total" do
    refute(@lukes_vacation.paid?, "not paid yet")
    assert_equal(0, @lukes_vacation.changes.size, "nothing to be saved to the DB")

    # Adjust this so this test can run, since it needs
    # to be in a period that has not been posted.
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: 2017, month: 6 # before July 2017
    lpp.save!

    @lukes_vacation.prep_print
    assert(@lukes_vacation.vacation_pay, "has vacation pay")
    refute(@lukes_vacation.paid?, "paid now")
  end

  test "Supplemental Days" do
    # You get supplemental days each month, no longer on your anniversary.
    # or when you take vacation.
    # for 27 years, this is 2 days per each 5 years of service (or 10 days)
    on_sep_5 do #2017
      employee = return_valid_employee()
      employee.contract_start = "1990-09-02"

      period = Period.current
      assert_equal(
          ((10/12.0) * 1).round(3),
          Vacation.period_supplemental_days(employee, period).round(3), "Correct Suppl Days")
    end

    # Still given out (1 month's worth) even though it is not an anniversary
    on_sep_5 do #2017
      employee = return_valid_employee()
      employee.contract_start = "1990-05-02"

      period = Period.current
      assert_equal(
          ((10/12.0) * 1).round(3),
          Vacation.period_supplemental_days(employee, period).round(3), "Correct Suppl Days")
    end
  end

  test "mom_supplemental_days and period_supplemental_days" do
    Date.stub :today, Date.new(2018, 5, 18) do
      employee = return_valid_employee()
      employee.contract_start = "2008-07-28"
      employee.person.gender = "female"
      child = Child.new
      child.birth_date = "2013-01-13"
      child.first_name = "Bob"
      child.last_name = "Hob"
      employee.person.children << child
      assert(child.valid?)
      assert(employee.valid?)

      assert_equal(1, employee.children_under_6)

      msd = Vacation.mom_supplemental_days(employee)
      assert_equal(0.17, msd.round(2), "should get 2 days per year, so 0.167 monthly")
      assert_equal(0.50, Vacation.period_supplemental_days(employee, Period.new(2018,1)).round(2))
    end
  end

  test "Supplemental Mom Days" do
    Date.stub :today, Date.new(2021, 1, 22) do
      employee = return_valid_employee()
      employee.contract_start = "2018-12-10"
      employee.first_day = "2018-12-10"
      employee.person.gender = "female"

      employee.person.children << Child.create(birth_date: "2016-04-13",
          first_name: "C", last_name: "One")
      employee.person.children << Child.create(birth_date: "2017-11-09",
          first_name: "C", last_name: "Two")
      employee.person.children << Child.create(birth_date: "2010-03-21",
          first_name: "C", last_name: "Three")

      assert_equal(2, employee.children_under_6)
      assert_equal(3, employee.children_under_19)

      msd = Vacation.mom_supplemental_days(employee)
      assert_equal(0.33, msd.round(2), "should get 2 days per child per year")
      assert_equal(0.33, Vacation.period_supplemental_days(employee, Period.new(2018,1)).round(2))
    end
  end

  test "Supplemental Mom Days Not If Male" do
    Date.stub :today, Date.new(2021, 1, 22) do
      employee = return_valid_employee()
      employee.contract_start = "2018-12-10"
      employee.first_day = "2018-12-10"
      employee.person.gender = "male"

      employee.person.children << Child.create(birth_date: "2016-04-13",
          first_name: "C", last_name: "One")
      employee.person.children << Child.create(birth_date: "2017-11-09",
          first_name: "C", last_name: "Two")
      employee.person.children << Child.create(birth_date: "2010-03-21",
          first_name: "C", last_name: "Three")

      assert_equal(2, employee.children_under_6)
      assert_equal(3, employee.children_under_19)

      msd = Vacation.mom_supplemental_days(employee)
      assert_equal(0.00, msd.round(2), "should get 0")
      assert_equal(0.00, Vacation.period_supplemental_days(employee, Period.new(2018,1)).round(2))
    end
  end

  test "Days balance rounded if necessary during payslip calc" do
    sept = Period.new(2018,9)
    oct = Period.new(2018,10)

    # Need to have a payslip in the start_date Period
    employee = return_valid_employee()
    employee.first_day = '2018-01-01'
    employee.save

    sept_ps = employee.payslip_for(sept)
    sept_ps = create_and_return_payslip(employee, sept) if (sept_ps.nil?)

    # This will round up to 20, else it will be an error.
    sept_ps.vacation_balance = 19.9999999999996
    sept_ps.vacation_pay_balance = 152423
    sept_ps.save

    # Create and init vacation
    vac = Vacation.new
    vac.employee = employee
    vac.start_date = "2018-10-01"
    vac.end_date = "2018-10-26"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")
    assert(vac.destroyable?)
    vac.paid = true

    assert_equal(20, vac.days, "should be 20 days")

    # Process october payslip, during which employee is on vacation for 20 days.
    payslip = Payslip.process(employee, oct)
    assert(payslip)
    # If insufficient balance, payslip will not be valid.
    assert(payslip.valid?, "should have no errors when processing")
  end

  def end_of_aug_vacay
    @luke.vacations.new(start_date: '2017-08-31', end_date: '2017-09-01')
  end

  def some_valid_params(mods={})
    {employee: @luke, start_date: '2017-09-09', end_date: '2017-09-10'}.merge(mods)
  end
end
