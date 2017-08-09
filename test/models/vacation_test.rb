require "test_helper"

class VacationTest < ActiveSupport::TestCase
  def setup
    super
    @luke = employees :Luke
  end

  test "Check presence of required attributes (which is all of them)" do
    params = {employee: @luke, start_date: '2017-08-09', end_date: '2017-08-10'}
    model_validation_hack_test Vacation, params
  end

  # TODO Invalid start and end dates, end date before start date, overlaps existing. Start=end date ok
end
