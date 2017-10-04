require "test_helper"

class LastPostedPeriodTest < ActiveSupport::TestCase
  def setup
    @july17 = last_posted_periods :July17
  end

  test "Get" do
    exp = Period.new(2017, 7)
    assert_equal exp, LastPostedPeriod.get
  end

  test "Set" do
    LastPostedPeriod.set 2017, 8
    assert_equal Period.new(2017, 8), LastPostedPeriod.get
    assert_equal 1, LastPostedPeriod.all.count
  end

  test "Initial Set" do
    LastPostedPeriod.first.destroy!
    assert_nil LastPostedPeriod.get
    LastPostedPeriod.set(2017, 8)
    assert_equal Period.new(2017, 8), LastPostedPeriod.get
  end
end
