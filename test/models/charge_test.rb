require "test_helper"

class ChargeTest < ActiveSupport::TestCase
  def setup
    @lukes_coke = charges :LukesCoke
    @luke = employees :Luke
  end

  test "Relations" do
    assert_equal @luke, @lukes_coke.employee
  end

  test "Validation" do
    model_validation_hack_test Charge, some_valid_params

    charge = Charge.new(some_valid_params.merge(amount: 'five'))
    refute charge.valid?

    charge = Charge.new(some_valid_params.merge(date: 'the twelfth'))
    refute charge.valid?
  end

  def some_valid_params
    {amount: 10, employee: @luke, date: '2017-08-15'}
  end
end
