require "test_helper"

class BonusTest < ActiveSupport::TestCase
  def bonus
    @bonus ||= Bonus.new
  end

  def test_valid

    bonus.name = "Test Bonus"
    bonus.quantity = 20.2

    assert_raise(ArgumentError) do
      bonus.bonus_type = "invalid"
    end

    assert_nothing_raised do
      bonus.bonus_type = "percentage"
    end

    assert_nothing_raised do
      bonus.bonus_type = "fixed"
    end

    assert bonus.valid?
  end


  def test_amount_must_by_number

    bonus.name = "Test Bonus"
    bonus.quantity = "QUANTITY"
    bonus.bonus_type = "percentage"

    refute bonus.valid?

    bonus.quantity = 234.0

    assert bonus.valid?
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test Bonus, {
            name: "Test Bonus",
            quantity: 20.1,
            bonus_type: "percentage"
    }
  end

end
