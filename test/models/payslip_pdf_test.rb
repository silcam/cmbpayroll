require "test_helper"
require 'payslip_generator'

class PayslipPdfTest < ActiveSupport::TestCase
  include PayslipGenerator

  def setup
    # Since I do some migration "magic" in other tests
    # there will be errors unless this is done.
    Payslip.reset_column_information
  end

  test "Vacation information is not displayed on pdf payslip for non-accruers" do
    employee = return_valid_employee()
    employee.accrue_vacation = false
    employee.category = "seven"
    employee.echelon = "b"
    period = Period.new(2018,10)

    generate_work_hours employee, period
    oct_payslip = Payslip.process(employee, period)
    pdf = pdf_generator(oct_payslip)

    pdf_analysis = PDF::Inspector::Text.analyze(pdf)
    refute(pdf_analysis.strings.include?('CONGE ACCUMULÉ'),
        "should not display vacation if not accruing")

    employee.accrue_vacation = true
    employee.save

    oct_payslip = Payslip.process(employee, period)
    pdf = pdf_generator(oct_payslip)

    pdf_analysis = PDF::Inspector::Text.analyze(pdf)
    assert(pdf_analysis.strings.include?('CONGE ACCUMULÉ'),
        "should display vacation totals")
  end

  test "Categories and Echelons Are Historical and Display Properly" do
    employee = return_valid_employee()
    employee.category = "seven"
    employee.echelon = "b"
    period = Period.new(2018,10)

    generate_work_hours employee, period
    oct_payslip = Payslip.process(employee, period)

    assert_equal(6, oct_payslip.category)
    assert_equal(7, display_category(oct_payslip.category))
    assert_equal("VII", display_category_roman(oct_payslip.category))
    assert_equal(14, oct_payslip.echelon)
    assert_equal("B", display_echelon(oct_payslip.echelon))

    # get a raise
    employee.category = "seven"
    employee.echelon = "c"
    period = Period.new(2018,11)

    generate_work_hours employee, period
    nov_payslip = Payslip.process(employee, period)

    assert_equal(6, nov_payslip.category)
    assert_equal(7, display_category(nov_payslip.category))
    assert_equal("VII", display_category_roman(nov_payslip.category))
    assert_equal(15, nov_payslip.echelon)
    assert_equal("C", display_echelon(nov_payslip.echelon))
  end

  def send_data(data, other = {})
    return data
  end

end
