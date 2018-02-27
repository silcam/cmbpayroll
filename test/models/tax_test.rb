require "test_helper"

class TaxTest < ActiveSupport::TestCase

  # The commented tests will be re-added once
  # the full CNPSWage calcualtion is complete.

  test "Can compute tax information" do
    employee = return_valid_employee()
    employee.category = "seven"
    employee.echelon = "a"

    tax = Tax.compute_taxes(employee, 123345, 123345)

    refute(tax.nil?, "not nil")
    assert(tax.valid?, "is valid")

    assert_equal(123250, tax.grosspay, "rounding is correct")
    assert_equal(1232, tax.ccf(), "ccf")
    assert_equal(1950, tax.crtv(), "crtv")
    assert_equal(4287, tax.proportional(), "prportional tax")
    assert_equal(429, tax.cac(), "cac")
    assert_equal(250, tax.communal(), "communal tax")
    assert_equal(123345, tax.cnpswage(), "cnps wage")
    assert_equal(5180, tax.cnps(), "cnps tax")
    assert_equal(0, tax.cac2(), "cac2")
  end

  test "Test Payslip 72474" do
    employee = return_valid_employee()

    employee.category = "eight"
    employee.echelon = "b"
    employee.gender = "male"
    employee.spouse_employed = false

    assert_equal(184485, employee.wage)
    assert_equal(172960, employee.find_base_wage)

    tax = Tax.compute_taxes(employee, 273238, 253238)

    assert_equal(273000, tax.grosspay, "rounding is correct")

    assert_equal(3250, tax.crtv())
    assert_equal(2730, tax.ccf())
    assert_equal(14476, tax.proportional())
    assert_equal(1448, tax.cac())

    assert_equal(666, tax.communal())
    assert_equal(253238, tax.cnpswage())
    assert_equal(10636, tax.cnps())
    assert_equal(0, tax.cac2())
  end

  test "Test Payslip 72480" do
    employee = return_valid_employee()

    tax = Tax.compute_taxes(employee, 97360, 77360)

    assert_equal(97250, tax.grosspay, "rounding is correct")

    assert_equal(750, tax.crtv())
    assert_equal(972, tax.ccf())
    assert_equal(2518, tax.proportional())
    assert_equal(252, tax.cac())

    assert_equal(166, tax.communal())
    assert_equal(77360, tax.cnpswage())
    assert_equal(3249, tax.cnps())
    assert_equal(0, tax.cac2())
  end

  test "Test Payslip 73287" do
    employee = return_valid_employee()
    employee.gender = "female"
    employee.spouse_employed = true

    tax = Tax.compute_taxes(employee, 437216, 417216)

    assert_equal(437000, tax.grosspay, "rounding is correct")

    assert_equal(5850, tax.crtv())
    assert_equal(4370, tax.ccf())
    assert_equal(25635, tax.proportional())
    assert_equal(2564, tax.cac())

    assert_equal(0, tax.communal())
    assert_equal(417216, tax.cnpswage())
    assert_equal(17523, tax.cnps())
    assert_equal(0, tax.cac2())
  end

  test "Test CNPS Ceiling (750000)" do
    employee = return_valid_employee()
    employee.gender = "male"
    employee.spouse_employed = true

    tax = Tax.compute_taxes(employee, 443500, 423500)

    # default ceiling
    assert_equal(750000, SystemVariable.value(:cnps_ceiling))

    # 4.2%
    assert_equal(17787, tax.cnps())

    # if >= 750 000, that's the maximum that will be used
    tax = Tax.compute_taxes(employee, 943500, 923500)
    assert_equal(31500, tax.cnps())

    # recompute based on ceiling of 800 000
    SystemVariable.create!(key: :cnps_ceiling, value: 800000)
    tax = Tax.compute_taxes(employee, 943500, 923500)
    assert_equal(33600, tax.cnps())
  end

  test "Can Figure out Taxes if missing in table" do
    employee = return_valid_employee()
    employee.category = "seven"
    employee.echelon = "a"

    # this isn't in the table
    tax = Tax.compute_taxes(employee, 5234345, 5234345)

    # but these still work
    assert_equal(5234250, tax.grosspay, "rounding is correct")
    assert_equal(52342, tax.ccf(), "ccf")
    assert_equal(68250, tax.crtv(), "crtv")
    assert_equal(251244, tax.proportional(), "prportional tax")
    assert_equal(25124, tax.cac(), "cac")
    assert_equal(5234345, tax.cnpswage(), "cnps wage")
    assert_equal(31500, tax.cnps(), "cnps tax") # ceiling
    assert_equal(0, tax.cac2(), "cac2")
    assert_equal(250, tax.communal(), "communal tax")
    assert_equal(428710, tax.total_tax(), "total_tax")
  end

  test "round down logic" do
    assert_equal(0, Tax.roundpay(0))
    assert_equal(0, Tax.roundpay(123))
    assert_equal(250, Tax.roundpay(333))
    assert_equal(750, Tax.roundpay(940))
    assert_equal(1000, Tax.roundpay(1000))
    assert_equal(934000, Tax.roundpay(934000))
    assert_equal(934000, Tax.roundpay(934123))
    assert_equal(934250, Tax.roundpay(934250))
    assert_equal(934250, Tax.roundpay(934251))
    assert_equal(934250, Tax.roundpay(934499))
    assert_equal(934500, Tax.roundpay(934500))
    assert_equal(934500, Tax.roundpay(934501))
    assert_equal(934500, Tax.roundpay(934698))
    assert_equal(934500, Tax.roundpay(934749))
    assert_equal(934750, Tax.roundpay(934750))
    assert_equal(934750, Tax.roundpay(934751))
    assert_equal(934750, Tax.roundpay(934984))
    assert_equal(934750, Tax.roundpay(934999))
    assert_equal(935000, Tax.roundpay(935000))
  end

end
