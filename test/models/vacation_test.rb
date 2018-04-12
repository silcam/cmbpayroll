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

  test "Days Earned" do
    # Before hire
    assert_equal 0, Vacation.days_earned(@luke, Period.new(2016, 11))

    # Normal month
    assert_equal 1.5, Vacation.days_earned(@luke, Period.new(2017, 1))

    # Supp Days
    assert_equal 1.5, Vacation.days_earned(@luke, Period.new(2021, 1))
    assert_equal 3.5, Vacation.days_earned(@luke, Period.new(2022, 1))
    assert_equal 1.5, Vacation.days_earned(@luke, Period.new(2022, 2))
    assert_equal 3.5, Vacation.days_earned(@luke, Period.new(2026, 1))
    assert_equal 5.5, Vacation.days_earned(@luke, Period.new(2027, 1))
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

  test "Vacation Can Figure Daily Vacation Rate" do
    employee = return_valid_employee()

    pay = Payslip.find_pay(employee)
    assert_equal(3405.167, Vacation.vacation_daily_rate(pay).round(3))
  end

  test "Vacation knows how much should be paid for vacations" do
    pay = Payslip.find_pay(@luke)
    vacation_rate = Vacation.vacation_daily_rate(pay)

    assert_equal(21, @lukes_vacation.days, "luke 21 days off to go to Kribi")
    assert_equal((21 * vacation_rate).ceil, @lukes_vacation.vacation_pay,
        "luke gets his vacation daily rate for each of the 21 days off he went to Kribi")
  end

  test "Vacation (payslip) can figure how much taxes are for this vacation" do
    pay = Payslip.find_pay(@luke)
    vacation_rate = Vacation.vacation_daily_rate(pay)

    assert_equal(21, @lukes_vacation.days, "luke 21 days off to go to Kribi")
    assert_equal((21 * vacation_rate).ceil, @lukes_vacation.vacation_pay,
        "luke gets his vacation daily rate for each of the 21 days off he went to Kribi")

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

  test "printing makes paid and saves vacation pay total" do
    refute(@lukes_vacation.paid?, "not paid yet")
    assert_equal(0, @lukes_vacation.changes.size, "nothing to be saved to the DB")

    @lukes_vacation.prep_print
    assert_equal(2, @lukes_vacation.changes.size, "vacation pay and paid to be saved to the DB #{@lukes_vacation.changes.inspect}")
    assert(@lukes_vacation.paid?, "paid now")
  end

  # test "Missed Days and Hours" do
  #   june = Period.new(2017, 6)
  #   assert_equal 5, Vacation.missed_days(@anakin, june)
  #   assert_equal 40, Vacation.missed_hours(@anakin, june)
  #   Date.stub :today, Date.new(2017, 6, 7) do
  #     assert_equal 2, Vacation.missed_days_so_far(@anakin)
  #     assert_equal 16, Vacation.missed_hours_so_far(@anakin)
  #   end
  # end

  def end_of_aug_vacay
    @luke.vacations.new(start_date: '2017-08-31', end_date: '2017-09-01')
  end

  def some_valid_params(mods={})
    {employee: @luke, start_date: '2017-09-09', end_date: '2017-09-10'}.merge(mods)
  end
end
