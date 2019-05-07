require "test_helper"

class VacationTest < ActiveSupport::TestCase
  def setup
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

    assert_equal(0, Vacation.earned_supplemental_days(employee, Period.new(2013, 1)))
  end

  test "Number of Supplemental Days Earned is correct" do
    @luke.contract_start = "2012-08-01"
    @luke.first_day = "2012-08-01"

    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2013, 1)))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2017, 1)))

    # Anniversary
    earned_days = 1.5 + ((2/12.0) * 8)
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

    earned_days = 1.5 + ((2/12.0) * 4)

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

  test "Supplemental Days Earned due to Anniversary" do
    # @luke contract_start: 2017-01-01

    # Before hire
    assert_equal 0, Vacation.days_earned(@luke, Period.new(2016, 11))

    # Normal month
    assert_equal 1.5, Vacation.days_earned(@luke, Period.new(2017, 1))

    # Supp Days
    assert_equal 1.5, Vacation.days_earned(@luke, Period.new(2021, 1))

    # Clear transfers
    @luke.supplemental_transfers.delete_all
    refute(@luke.last_supplemental_transfer)

    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2021, 12)))

    earned_days = 1.5 + (2/12.0 * 1)
    assert_equal(earned_days, Vacation.days_earned(@luke, Period.new(2022, 1)))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2022, 2)))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2022, 3)))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2025, 12)))
    earned_days = 1.5 + (2/12.0 * (4 * 12))
    assert_equal(earned_days.round(2), Vacation.days_earned(@luke, Period.new(2026, 1)).round(2))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2026, 2)))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2026, 12)))
    earned_days = 1.5 + (2/12.0 * 11) + (4/12.0 * 1)
    assert_equal(earned_days.round(2), Vacation.days_earned(@luke, Period.new(2027, 1)).round(2))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2027, 2)))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2027, 3)))
  end

  test "Supplemental Days Earned due to Vacation" do
    # @luke contract_start: 2017-01-01

    # Before hire
    assert_equal(0, Vacation.days_earned(@luke, Period.new(2016, 11)))

    # Normal month
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2017, 1)))

    # Clear transfers
    @luke.supplemental_transfers.delete_all
    refute(@luke.last_supplemental_transfer)

    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2021, 1)))

    earned_days = 1.5 + (2/12.0) * 1
    assert_equal(earned_days, Vacation.days_earned(@luke, Period.new(2022, 1)))

    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2022, 2)))
    Vacation.create!(start_date: "2022-03-03", end_date: "2022-03-04", employee: @luke)

    earned_days = 1.5 + ((2/12.0) * 2)
    assert_equal(earned_days.round(3), Vacation.days_earned(@luke, Period.new(2022, 3)).round(3))
    assert_equal(1.5, Vacation.days_earned(@luke, Period.new(2022, 4)))
  end

  test "Supplemental Transfer should happen when vacations happen" do
    # Create a vacation that starts in a certain period.
    Vacation.create!(start_date: "2018-11-03", end_date: "2018-12-03", employee: @luke)

    refute(Vacation.transfer_supplemental_days?(@luke, Period.new(2018,10)), "shouldn't transfer")
    assert(Vacation.transfer_supplemental_days?(@luke, Period.new(2018,11)), "should transfer")
    refute(Vacation.transfer_supplemental_days?(@luke, Period.new(2018,12)), "shouldn't transfer")
  end

  test "Supplemental Transfer should happen when anniversary (contract start) happens" do
    assert_equal(0, Vacation.for_period(Period.new(2020,1)).size,
        "there should not be vacations during this period")

    refute(Vacation.transfer_supplemental_days?(@luke, Period.new(2019,12)), "shouldn't transfer")
    assert(Vacation.transfer_supplemental_days?(@luke, Period.new(2020,1)), "should transfer")
    refute(Vacation.transfer_supplemental_days?(@luke, Period.new(2020,2)), "shouldn't transfer")
  end

  test "Supplemental Transfer sets last_supplemental_transfer employee attribute" do
    employee = return_valid_employee()
    employee.contract_start = "2013-08-01"
    employee.first_day = "2013-08-01"

    refute(employee.last_supplemental_transfer, "should not have transfer date")

    # transfer days

    earned_days = 1.5 + (2/12.0 * 8)
    assert_equal(earned_days, Vacation.days_earned(employee, Period.new(2018, 8)),
        "earned supplemental days sets the transfer date")

    # assert existence (won't pull from current period)
    refute(employee.last_supplemental_transfer(Period.new(2018, 8)))
    assert(employee.last_supplemental_transfer(Period.new(2018, 9)))
    assert_equal("2018-08-01", employee.last_supplemental_transfer(Period.new(2018,9)).strftime("%Y-%m-%d"),
        "date is now set")

    # transfer days
    assert_equal(3.5, Vacation.days_earned(employee, Period.new(2019, 8)),
        "earning more days resets the transfer date")

    # assert updated
    assert(employee.last_supplemental_transfer(Period.new(2019, 8)))
    assert_equal("2018-08-01", employee.last_supplemental_transfer(Period.new(2019,8)).strftime("%Y-%m-%d"),
        "date is updated")

    # won't pull from future
    assert(employee.last_supplemental_transfer(Period.new(2019, 7)))
    assert_equal("2018-08-01", employee.last_supplemental_transfer(Period.new(2019,7)).strftime("%Y-%m-%d"),
        "date is updated")

    # Ahh
    assert(employee.last_supplemental_transfer(Period.new(2019, 9)))
    assert_equal("2019-08-01", employee.last_supplemental_transfer(Period.new(2019,9)).strftime("%Y-%m-%d"),
        "date is updated")
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

    # make payslip valid.
    payslip.net_pay = 342345
    create_earnings(payslip)
    set_previous_vacation_balances(@luke, period, 286978, 42.0)

    # Set up balances.
    payslip.vacation_balance = 42.0
    payslip.vacation_pay_balance = 286978
    assert(payslip.save, "should save properly")

    payslip = Payslip.process(@luke, period)

    payslip.vacation_daily_rate

    # Vacation pay is computed by vacation_daily_rate * days
    exp = @lukes_vacation.vacation_pay
    assert_equal(21, @lukes_vacation.days, "luke 21 days off to go to Kribi")
    assert_equal(exp, @lukes_vacation.vacation_pay, "vacation pay is correct for vacation")

    # original balance + normal accrual - vacation days taken
    assert_equal(42 + 1.5 - 21, payslip.vacation_balance)
    # original balance - vacation pay
    assert_equal(286978 - exp, payslip.vacation_pay_balance)
  end

  test "Vacation (payslip) can figure how much taxes are for this vacation" do
    period = Period.from_date(@lukes_vacation.start_date)
    payslip = @luke.payslip_for(period)
    assert(payslip, "payslip exists")

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

    exp_rate = payslip.compute_fullcnpswage * 12 / 16.0 / 18.0
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
    vac.end_date = "2018-09-07"
    assert(vac.valid?, "newly created vacation should be valid now")
    assert(vac.save, "newly created vacation saves fine")

    period = Period.from_date(vac.start_date)

    hours = {
      "2018-09-10" => {hours: 8},
      "2018-09-11" => {hours: 8},
      "2018-09-12" => {hours: 8},
      "2018-09-13" => {hours: 8},
      "2018-09-14" => {hours: 8},
      "2018-09-17" => {hours: 8},
      "2018-09-18" => {hours: 8},
      "2018-09-19" => {hours: 8},
      "2018-09-20" => {hours: 8},
      "2018-09-21" => {hours: 8},
      "2018-09-24" => {hours: 8},
      "2018-09-25" => {hours: 8},
      "2018-09-26" => {hours: 8},
      "2018-09-27" => {hours: 8},
      "2018-09-28" => {hours: 8}
    }

    success, errors = WorkHour.update(@luke, hours)
    assert(success, "should not have produced these errors: #{errors.inspect}")

    payslip = Payslip.process(@luke, period)
    assert(payslip, "payslip exists")

    set_previous_vacation_balances(@luke, period, 286978, 42.0)
    payslip = Payslip.process(@luke, period)

    # Set up balances.
    payslip.vacation_balance = 42.0
    payslip.vacation_pay_balance = 286978
    assert(payslip.save, "should save properly")

    # Do the test.
    assert_equal(5, vac.days, "luke 21 days off to go to Kribi")

    # force the items to get in the DB
    vac.prep_print

    exp_rate = payslip.compute_fullcnpswage * 12 / 16.0 / 18.0
    assert_equal(exp_rate, payslip.vacation_daily_rate, "can compute vacation rate")

    assert_equal(21441, vac.vacation_pay, "correct vac_pay")
    assert_equal(3063, vac.total_tax, "correct tax")

    tax_obj = vac.get_tax
    # verify all tax components are stored.
    assert_equal(vac.ccf, tax_obj.ccf)
    assert_equal(vac.crtv, tax_obj.crtv)
    assert_equal(vac.proportional, tax_obj.proportional)
    assert_equal(vac.cac, tax_obj.cac)
    assert_equal(vac.cac2, tax_obj.cac2)
    assert_equal(vac.communal, tax_obj.communal)
    assert_equal(vac.cnps, tax_obj.cnps)
    assert_equal(vac.total_tax, tax_obj.total_tax)
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

    # This is the vacation calculation
    exp = sept_ps.compute_fullcnpswage * 12 / 16.0 / 18.0

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

  test "printing makes paid and saves vacation pay total" do
    refute(@lukes_vacation.paid?, "not paid yet")
    assert_equal(0, @lukes_vacation.changes.size, "nothing to be saved to the DB")

    @lukes_vacation.prep_print
    assert(@lukes_vacation.vacation_pay, "has vacation pay")
    assert(@lukes_vacation.paid?, "paid now")
  end

  test "Supplemental Days" do
    # You get your supplemental days on your anniversary.
    # All at once.
    on_sep_5 do #2017
      employee = return_valid_employee()
      employee.contract_start = "1990-09-02"

      employee.last_supplemental_transfer = Date.parse("2016-09-05")
      period = Period.current
      assert_equal(10, Vacation.supplemental_days(employee, period), "Correct Suppl Days")
    end

    # Other months you get nothing.
    on_sep_5 do #2017
      employee = return_valid_employee()
      employee.contract_start = "1990-05-02"

      period = Period.current
      assert_equal(0, Vacation.supplemental_days(employee, period), "Correct Suppl Days")
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
      assert_equal(2, msd, "should get 2 days")
      assert_equal(2.33, Vacation.period_supplemental_days(employee, Period.new(2018,1)).round(2))
    end
  end

  def end_of_aug_vacay
    @luke.vacations.new(start_date: '2017-08-31', end_date: '2017-09-01')
  end

  def some_valid_params(mods={})
    {employee: @luke, start_date: '2017-09-09', end_date: '2017-09-10'}.merge(mods)
  end
end
