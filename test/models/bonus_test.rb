require "test_helper"

class BonusTest < ActiveSupport::TestCase
  def bonus
    @bonus ||= Bonus.new
  end

  def test_valid

    bonus.name = "Test Bonus"

    assert_raise(ArgumentError) do
      bonus.bonus_type = "invalid"
    end

    assert_nothing_raised do
      bonus.quantity = 20
      bonus.bonus_type = "fixed"
    end

    assert_nothing_raised do
      bonus.quantity = 20.2
      bonus.bonus_type = "percentage"
    end

    assert bonus.valid?, "bonus is valid"
  end


  def test_amount_must_be_number

    bonus.name = "Test Bonus"

    assert_raise(ActiveRecord::RecordInvalid) do
      bonus.quantity = "QUANTITY"
      bonus.percentage!
    end

    assert bonus.percentage?, "bonus should be a percentage"

    bonus.quantity = 84.0
    bonus.percentage!

    assert bonus.valid?, "valid quantity"

    assert_raise(ActiveRecord::RecordInvalid) do
      bonus.quantity = "-100"
      bonus.fixed!
    end

    refute bonus.valid?, "cannot be negative"

    bonus.quantity = 100
    bonus.fixed!

    assert bonus.valid?, "valid input"
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test Bonus, {
            name: "Test Bonus",
            quantity: 20.1,
            bonus_type: "percentage"
    }
  end

  def test_valid_input_formats

    bonus.name = "Test Bonus"
    bonus.quantity = "100.1"
    bonus.bonus_type = "percentage"
    refute bonus.valid?, "cannot have percentage above 100"

    bonus.name = "Test Bonus"
    bonus.quantity = "100.5"
    bonus.bonus_type = "fixed"
    refute bonus.valid?, "cannot have fractional CFA"

  end

  def test_display_quantity_for_humans

    bonus.name = "Test Bonus"
    bonus.quantity = "34.0"
    bonus.bonus_type = "percentage"
    assert bonus.valid?

    assert_equal("34.0000%", bonus.display_quantity)

    bonus.quantity = "5236"
    bonus.bonus_type = "fixed"

    assert_equal("5 236 FCFA", bonus.display_quantity)

    bonus.quantity = "34.66666666666666666"
    bonus.bonus_type = "percentage"

    assert_equal("34.6667%", bonus.display_quantity)

    bonus.quantity = "5236"
    bonus.bonus_type = "fixed"

    assert_equal("5 236 FCFA", bonus.display_quantity, "cannot have fractional CFA")

  end

end
