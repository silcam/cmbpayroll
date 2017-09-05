require "test_helper"

class VacationTest < ActiveSupport::TestCase
  def setup
    @luke = employees :Luke
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
    params = some_valid_params end_date: '2017-08-08'
    refute Vacation.new(params).valid?
  end

  test "End date and start date the same ok" do
    params = some_valid_params
    params[:end_date] = params[:start_date]
    assert Vacation.new(params).valid?
  end

  test "Vacations can't overlap existing" do
    invalids = [{employee: @luke, start_date: '2017-06-15', end_date: '2017-07-01'},
                {employee: @luke, start_date: '2017-07-31', end_date: '2017-07-31'},
                {employee: @luke, start_date: '2017-07-15', end_date: '2017-07-17'},
                {employee: @luke, start_date: '2017-07-15', end_date: '2017-08-01'},
                {employee: @luke, start_date: '2017-06-30', end_date: '2017-08-01'}]
    invalids.each do |params|
      refute Vacation.new(params).valid?, "Vacation from #{params[:start_date]} to #{params[:end_date]} overlaps"
    end
  end

  test "Vacation can obviously overlap itself" do
    assert @lukes_vacation.update end_date: '2017-07-30'
  end

  test "No Overlapped Work Hours" do
    v = Vacation.new(some_valid_params)
    assert_empty v.overlapped_work_hours
    refute v.overlaps_work_hours?
  end

  test "Overlaps overtime at start date" do
    v = Vacation.new some_valid_params(start_date: @lukes_overtime.date)
    assert_includes v.overlapped_work_hours, @lukes_overtime
    assert v.overlaps_work_hours?
  end

  test "Overlaps overtime at end date" do
    v = Vacation.new some_valid_params(start_date: '2017-08-01', end_date: @lukes_overtime.date)
    assert_includes v.overlapped_work_hours, @lukes_overtime
  end

  test "Overlaps overtime in the middle" do
    v = Vacation.new some_valid_params( start_date: '2017-08-01')
    assert_includes v.overlapped_work_hours, @lukes_overtime
  end

  test "Overlapped WorkHours don't include entries with 0 hrs" do
    day_off = WorkHour.create!(employee: @luke, date: '2017-08-09', hours: 0)
    v = Vacation.new some_valid_params
    refute_includes v.overlapped_work_hours, day_off
  end


  def some_valid_params(mods={})
    {employee: @luke, start_date: '2017-08-09', end_date: '2017-08-10'}.merge(mods)
  end
end
