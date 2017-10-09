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
    @luke.vacations << Vacation.new(start_date: '2017-08-08', end_date: '2017-08-08')
    assert_nil WorkHour.find_by id: lukes_day_off.id
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

  test "Days Hash" do
    days = Vacation.days_hash(@luke, Date.new(2017, 7, 30), Date.new(2017, 8, 2))
    assert_equal 2, days.length
    assert days[Date.new(2017, 7, 31)][:vacation]
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
