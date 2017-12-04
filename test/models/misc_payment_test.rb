require "test_helper"

class MiscPaymentTest < ActiveSupport::TestCase
  def setup
    @lukes_august_bonus = misc_payments :LukesAugustBonus
    @luke = employees :Luke
  end

  test "Relations" do
    assert_equal @luke, @lukes_august_bonus.employee
  end

  test "Validation" do
    model_validation_hack_test MiscPayment, some_valid_params

    mp = MiscPayment.new(some_valid_params.merge(amount: 'five'))
    refute mp.valid?

    mp = MiscPayment.new(some_valid_params.merge(date: 'the twelfth'))
    refute mp.valid?
  end

  test "Invalid Dates" do
    on_sep_5 do
      # Can't add charges during posted pay period
      mp = MiscPayment.new some_valid_params.merge(date: '2017-07-31')
      refute mp.valid?
      mp.date = '2017-08-01'
      assert mp.valid?

      # Can't add charges in the future!
      mp.date = '2017-09-06'
      refute mp.valid?
      mp.date = '2017-09-05'
      assert mp.valid?
    end
  end

  test "Can't delete Charge from posted period" do
    LastPostedPeriod.post_current # Post August
    @lukes_august_bonus.destroy
    assert_includes MiscPayment.all, @lukes_august_bonus
  end

  test "Can delete charge during open period" do
    @lukes_august_bonus.destroy
    refute_includes MiscPayment.all, @lukes_august_bonus
  end

  def some_valid_params
    {amount: 10, employee: @luke, date: '2017-08-15'}
  end
end
