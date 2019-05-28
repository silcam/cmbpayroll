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

  test "Before tax requires value to ba valid" do
    mp = MiscPayment.new
    mp.date = "2018-10-11"
    mp.amount = 5000
    mp.employee = @luke

    assert_nil(mp.before_tax)
    refute mp.valid?
    assert(mp.errors.has_key?(:before_tax), "should have before tax error")
    assert_equal(1, mp.errors.size(), "should have before 1 error")

    mp.before_tax = true
    assert mp.valid?
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

  test "Readable by user" do
    all_mps = MiscPayment.all
    # Admin can read
    assert_includes MiscPayment.readable_by(all_mps, users(:MaceWindu)), @lukes_august_bonus

    # Sup can read
    assert_includes MiscPayment.readable_by(all_mps, users(:Yoda)), @lukes_august_bonus

    # User can read
    assert_includes MiscPayment.readable_by(all_mps, users(:Luke)), @lukes_august_bonus

    # Others can't read
    refute_includes MiscPayment.readable_by(all_mps, users(:Quigon)), @lukes_august_bonus
  end

  test "Can be selectable for tax purposes" do
    employee = return_valid_employee()

    mp = MiscPayment.new
    mp.date = '2018-03-15'
    mp.amount = 2345454
    mp.employee = employee
    mp.note = "This is a misc payment"

    refute(mp.before_tax, "should be after tax by default")

    mp.before_tax = true
    assert(mp.before_tax, "but can set to be before tax")
  end

  def some_valid_params
    {amount: 10, before_tax: true, employee: @luke, date: '2017-08-15'}
  end
end
