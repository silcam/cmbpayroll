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

  test "Invalid Dates" do
    on_sep_5 do
      # Can't add charges during posted pay period
      charge = Charge.new some_valid_params.merge(date: '2017-07-31')
      refute charge.valid?
      charge.date = '2017-08-01'
      assert charge.valid?

      # Can't add charges in the future!
      charge.date = '2017-09-06'
      refute charge.valid?
      charge.date = '2017-09-05'
      assert charge.valid?
    end
  end

  test "Can't delete Charge from posted period" do
    LastPostedPeriod.post_current # Post August
    @lukes_coke.destroy
    assert_includes Charge.all, @lukes_coke
  end

  test "Can delete charge during open period" do
    @lukes_coke.destroy
    refute_includes Charge.all, @lukes_coke
  end

  def some_valid_params
    {amount: 10, employee: @luke, date: '2017-08-15'}
  end
end
