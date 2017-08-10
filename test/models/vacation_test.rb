require "test_helper"

class VacationTest < ActiveSupport::TestCase
  def setup
    super
    @luke = employees :Luke
  end

  test "Check presence of required attributes (which is all of them)" do
    params = some_valid_params
    model_validation_hack_test Vacation, params
  end

  test "Start date not a date" do
    params = some_valid_params
    params[:start_date] = 'abc'
    refute Vacation.new(params).valid?
  end

  test "End date not a date" do
    params = some_valid_params
    params[:end_date] = 'abc'
    refute Vacation.new(params).valid?
  end

  test "End Date before start date fails validation" do
    params = some_valid_params
    params[:end_date] = '2017-08-08'
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
                {employee: @luke, start_date: '2017-07-15', end_date: '2017-08-01'}]
    invalids.each do |params|
      refute Vacation.new(params).valid?, "Vacation from #{params[:start_date]} to #{params[:end_date]} overlaps"
    end
  end

  def some_valid_params
    {employee: @luke, start_date: '2017-08-09', end_date: '2017-08-10'}
  end
end
