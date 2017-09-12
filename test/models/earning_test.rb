require "test_helper"

class EarningTest < ActiveSupport::TestCase

  test "must be valid" do
    earnings = Earning.new
    payslip = Payslip.new

    payslip.earnings << earnings

    refute(earnings.valid?)

    earnings.rate = 1

    refute(earnings.valid?)

    earnings.hours = 1

    assert(earnings.valid?)
  end

  test "earnings computations" do
    earnings = Earning.new
    payslip = Payslip.new

    payslip.earnings << earnings

    earnings.hours = 8
    earnings.rate = 1400

    assert(earnings.valid?)

    assert(earnings.total == 8 * 1400)
  end

  test "hours cannot be negative" do
    earnings = Earning.new
    payslip = Payslip.new

    payslip.earnings << earnings

    earnings.hours = -8
    earnings.rate = 1400

    refute(earnings.valid?, "cannot be valid with negative hours")

    assert_raise("Should raise an error if attempt to total an invalid object") do
        earnings.total
    end
  end


  test "rate cannot be negative" do
    earnings = Earning.new
    payslip = Payslip.new

    payslip.earnings << earnings

    earnings.hours = 8
    earnings.rate = -1400

    refute(earnings.valid?, "cannot be valid with a negative rate")

    assert_raise("Should raise an error if attempt to total an invalid object") do
        earnings.total
    end
  end

  test "records with zero hours are valid" do
    earnings = Earning.new
    payslip = Payslip.new

    payslip.earnings << earnings

    earnings.hours = 0
    earnings.rate = 0

    assert(earnings.valid?, "zeros are valid")

    assert_nothing_raised do
        assert_equal(earnings.total, 0)
    end
  end

  test "must have fixed amount or hours + rate to be valid" do
    earnings = Earning.new
    payslip = Payslip.new

    payslip.earnings << earnings

    earnings.amount = "27349"

    assert(earnings.valid?, "with amount earning is valid")

    assert_nothing_raised do
        assert_equal(earnings.total, 27349)
    end
  end

end
