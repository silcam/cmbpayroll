require "test_helper"

class DeductionTest < ActiveSupport::TestCase

  def test_must_be_valid

    payslip = Payslip.new
    deduction = Deduction.new

    payslip.deductions << deduction

    refute(deduction.valid?)

    deduction.note = "Cokes and Fantas from the Dining Hall"
    refute(deduction.valid?)

    deduction.date = Date.today
    refute(deduction.valid?)

    deduction.amount = 1000
    refute(deduction.valid?)

    deduction.deduction_type = Charge.charge_types["other"]
    assert(deduction.valid?, "valid when attributes are correct")

  end

  def test_deduction_happens_during_payslip_period

    payslip_period = Period.new(2017, 01) # January
    payslip = Payslip.from_period(payslip_period)

    deduction = Deduction.new
    deduction.note = "Cokes and Fantas from the Dining Hall"
    deduction.date = Date.today
    deduction.deduction_type = Charge.charge_types["other"]
    deduction.amount = 1000

    payslip.deductions << deduction

    deduction.valid?

    refute(deduction.valid?, "Date of deduction must be in the payslip period")

    deduction.date = Date.parse("2017-01-01T00:00:00+01:00") # border date
    assert(deduction.valid?, "Date on the border is fine")

    deduction.date = Date.parse("2017-01-31T23:59:59+01:00") # border date
    assert(deduction.valid?, "Date on the border is fine")

    deduction.date = Date.parse("2017-02-01T00:00:00+01:00") # past date
    refute(deduction.valid?, "Date past the border is not fine")

  end

  def test_cameroonian_localization

    deduction = Deduction.new
    deduction.note = "Non-Integer Number"
    deduction.date = Date.today

    deduction.amount = 999.9
    assert_equal("1 000 FCFA", number_to_currency(deduction.amount, locale: :cm))

    deduction.amount = 999.2
    assert_equal("999 FCFA", number_to_currency(deduction.amount, locale: :cm))

  end

end
