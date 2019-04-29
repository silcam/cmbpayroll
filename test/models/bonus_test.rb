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
      bonus.quantity = 0.202
      bonus.bonus_type = "percentage"
    end

    bonus.valid?
    assert bonus.valid?, "bonus is valid"
  end

  def test_amount_must_be_number
    bonus.name = "Test Bonus"

    assert_raise(ActiveRecord::RecordInvalid) do
      bonus.quantity = "QUANTITY"
      bonus.percentage!
    end

    assert bonus.percentage?, "bonus should be a percentage"

    bonus.quantity = 0.84
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

  def test_validate_presence_of_required_attributes
    model_validation_hack_test Bonus, {
      name: "Test Bonus",
      quantity: 0.201,
      bonus_type: "percentage"
    }
  end

  def test_can_set_a_minimum_bonus
    bonus.name = "Test with Minimum"
    bonus.bonus_type = "percentage"
    bonus.quantity = 0.05
    bonus.minimum = 7500
    assert bonus.maximum.nil?
    assert bonus.valid?

    assert_equal(7500, bonus.effective_bonus(2500))
    assert_equal(50000, bonus.effective_bonus(1000000))
  end

  def test_can_set_a_minimum_and_a_maximum
    bonus.name = "Test with Minimum"
    bonus.bonus_type = "percentage"
    bonus.quantity = 0.05
    bonus.minimum = 7500
    bonus.maximum = 15000
    assert bonus.valid?

    assert_equal(7500, bonus.effective_bonus(1500))
    assert_equal(7500, bonus.effective_bonus(2500))
    assert_equal(9000, bonus.effective_bonus(180000))
    assert_equal(15000, bonus.effective_bonus(300000))
    assert_equal(15000, bonus.effective_bonus(304000))
    assert_equal(15000, bonus.effective_bonus(1000000))
  end

  def test_minimum_cannot_be_more_than_maximum
    bonus.name = "Test with Minimum"
    bonus.bonus_type = "percentage"
    bonus.quantity = 0.05
    bonus.minimum = 10999
    bonus.maximum = 1000
    refute bonus.valid?
  end

  def test_cannot_have_minimum_and_fixed_CFA
    bonus.name = "Test Bonus"
    bonus.bonus_type = "percentage"
    bonus.ext_quantity = 30
    bonus.valid?
    assert bonus.valid?, "OK"
    bonus.minimum = 20000
    assert bonus.valid?, "cannot have minimum with percentage bonus"
  end

  def test_can_be_made_to_work_with_CaisseBase
    bonus.name = "Caisse Bonus"
    bonus.bonus_type = "percentage"
    bonus.quantity = 0.30
    assert bonus.valid?, "that looks good to me! #{bonus.errors.messages.inspect}"
    refute bonus.use_caisse, "should be false by default"

    bonus.use_caisse = true
    assert bonus.use_caisse, "is now using caisse"

    assert bonus.valid?, "Still valid!"
    assert bonus.save, "Totally saved"
  end

  def test_valid_input_formats
    bonus.name = "Test Bonus"
    bonus.bonus_type = "percentage"
    bonus.quantity = "100.1"
    refute bonus.valid?, "cannot have percentage above 100"

    bonus.name = "Test Bonus"
    bonus.bonus_type = "fixed"
    bonus.quantity = "100.5"
    refute bonus.valid?, "cannot have fractional CFA"

    bonus.name = "Test Bonus"
    bonus.bonus_type = "fixed"
    bonus.quantity = "100"
    assert bonus.valid?, "OK"
    bonus.maximum = "20000"
    refute bonus.valid?, "cannot have maximum with fixed CFA"

    bonus = Bonus.new

    bonus.name = "Test Bonus"
    bonus.bonus_type = "percentage"
    bonus.ext_quantity = 30
    bonus.valid?
    assert bonus.valid?, "OK"
    bonus.maximum = 20000
    assert bonus.valid?, "can have maximum with percentage bonus"

    bonus.maximum = "AAA"
    refute bonus.valid?, "can't be a string"

    bonus.maximum = 200.123
    refute bonus.valid?, "must be an integer"

    bonus.maximum = 200
    assert bonus.valid?, "OK"
  end

  def test_computes_effective_bonus
    bonus = Bonus.new
    bonus.name = "Test Bonus"
    bonus.bonus_type = "percentage"
    bonus.ext_quantity = 30

    assert_equal(45000, bonus.effective_bonus(150000))
    bonus.maximum = "20000"
    assert_equal(20000, bonus.effective_bonus(150000))

    bonus = Bonus.new
    bonus.name = "Test Bonus"
    bonus.bonus_type = "fixed"
    bonus.ext_quantity = 50000
    assert_equal(50000, bonus.effective_bonus(150000))
  end

  def test_ext_quantity
    bonus.name = "Ninety Five Percent"
    bonus.bonus_type = "percentage"
    bonus.ext_quantity = "95"
    assert bonus.valid?
    bonus.save
    assert_equal(0.95, bonus.quantity)

    bonus.name = "Twelve Percent"
    bonus.bonus_type = "percentage"
    bonus.ext_quantity = "12"
    assert bonus.valid?
    bonus.save
    assert_equal(0.12, bonus.quantity)

    bonus.name = "Slightly Less than 14 Percent"
    bonus.bonus_type = "percentage"
    bonus.ext_quantity = "13.999999"
    assert bonus.valid?
    bonus.save
    assert_equal(0.13999999, bonus.quantity)

    bonus.name = "Ten Thousant CFA"
    bonus.bonus_type = "fixed"
    bonus.ext_quantity = "10000"
    assert bonus.valid?
    bonus.save
    assert_equal(10000, bonus.quantity)
  end

  def test_display_quantity_for_humans
    bonus.name = "Test Bonus"
    bonus.bonus_type = "percentage"
    bonus.quantity = "0.34"
    assert bonus.valid?

    assert_equal("34%", bonus.display_quantity)

    bonus.quantity = "5236"
    bonus.bonus_type = "fixed"

    assert_equal("5 236 FCFA", bonus.display_quantity)

    bonus.bonus_type = "percentage"
    bonus.quantity = "0.3466666666666666666"

    assert_equal("34.66667%", bonus.display_quantity)

    bonus.quantity = "5236"
    bonus.bonus_type = "fixed"

    assert_equal("5 236 FCFA", bonus.display_quantity, "cannot have fractional CFA")
  end

  def test_bonus_type_has_base
    bonus.name = "Test Bonus just Base"

    assert_raise(ArgumentError) do
      bonus.bonus_type = "invalid"
    end

    assert_nothing_raised do
      bonus.quantity = 0.202
      bonus.bonus_type = "base_percentage"
    end
    refute bonus.use_caisse, "should be false by default"

    bonus.valid?
    assert bonus.valid?, "bonus is valid"
  end

  def test_base_bonus_can_be_seniority
    bonus.name = "Test Bonus Base and Seniority"

    assert_nothing_raised do
      bonus.quantity = 0.202
      bonus.bonus_type = "base_percentage"
    end

    refute bonus.use_caisse, "should be false by default"
    bonus.use_caisse = true
    assert bonus.use_caisse, "using seniority bonus"

    bonus.valid?
    assert bonus.valid?, "bonus is valid"
  end

end
