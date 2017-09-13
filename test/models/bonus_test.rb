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

  def test_display_quantity_for_humans

    bonus.name = "Test Bonus"
    bonus.quantity = "34.0"
    bonus.bonus_type = "percentage"
    assert bonus.valid?

    assert_equal("34%", bonus.display_quantity)

    bonus.quantity = "5236"
    bonus.bonus_type = "fixed"

    assert_equal("5236 FCFA", bonus.display_quantity)

    bonus.quantity = "34.66666666666666666"
    bonus.bonus_type = "percentage"

    assert_equal("34.67%", bonus.display_quantity)

    bonus.quantity = "5236.25"
    bonus.bonus_type = "fixed"

    assert_equal("5236.25 FCFA", bonus.display_quantity)

  end

end
