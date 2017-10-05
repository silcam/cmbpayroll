require "test_helper"

class LastPostedPeriodTest < ActiveSupport::TestCase
  def setup
    @july17 = last_posted_periods :July17
  end

  test "Get" do
    exp = Period.new(2017, 7)
    assert_equal exp, LastPostedPeriod.get
  end

  test "Current" do
    exp = Period.new(2017, 8)
    assert_equal exp, LastPostedPeriod.current
  end

  test "Current when empty" do
    Date.stub :today, Date.new(2017, 10, 31) do
      LastPostedPeriod.first.destroy!
      assert_nil LastPostedPeriod.get
      exp = Period.new(2017, 9)
      assert_equal exp, LastPostedPeriod.current
    end
  end

  test "Post Current" do
    LastPostedPeriod.post_current
    assert_equal Period.new(2017, 8), LastPostedPeriod.get
    assert_equal 1, LastPostedPeriod.all.count
  end

  test "Initial Post Current" do
    Date.stub :today, Date.new(2017, 10, 31) do
      LastPostedPeriod.first.destroy!
      assert_nil LastPostedPeriod.get
      LastPostedPeriod.post_current
      exp = Period.new(2017, 9)
      assert_equal exp, LastPostedPeriod.get
    end
  end

  test "posted?" do
    assert LastPostedPeriod.posted? Period.new(2017, 6)
    assert LastPostedPeriod.posted? Period.new(2017, 7)
    refute LastPostedPeriod.posted? Period.new(2017, 8)
  end
end
