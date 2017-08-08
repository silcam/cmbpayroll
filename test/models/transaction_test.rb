require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  def setup
    super
    @lukes_coke = transactions :LukesCoke
    @luke = employees :Luke
  end

  test "Relations" do
    assert_equal @luke, @lukes_coke.employee
  end
end
