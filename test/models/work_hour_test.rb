require "test_helper"

class WorkHourTest < ActiveSupport::TestCase
  def setup
    super
    @luke = employees :Luke
  end

  test "Validate Presence of Required Attributes" do
    params = {employee: @luke, date: '2017-08-09', hours: 9}
    model_validation_hack_test WorkHour, params
  end
end
