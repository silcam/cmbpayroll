require "test_helper"

class EmployeeYearlyReportTest < ActiveSupport::TestCase

  # Same shape as AnnualPayslipReport (see annual_payslip_report_test.rb),
  # except grouped by year only -- every processed month collapses into
  # a single row per employee per year, rather than one row per month.

  test "an empty year returns no rows without erroring" do
    rows = run_yearly_report("2018-1")
    assert_equal([], rows, "no payslips were processed in this year")
  end

  test "a processed payslip appears as the employee's yearly row, with totals matching the payslip record" do
    employee = return_valid_employee
    employee.cnps = "CNPS123"
    employee.niu = "NIU456"
    employee.save!

    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    payslip = Payslip.process(employee, july)

    row = find_row(run_yearly_report("2018-7"), employee)

    assert(row, "july's processed payslip should show up in 2018's yearly row")
    assert_equal(2018, row["py"].to_i)
    assert_equal("CNPS123", row["matricule_cnps"])
    assert_equal("NIU456", row["employee_niu"])
    assert_equal("#{employee.first_name} #{employee.last_name}", row["employee_name"])

    assert_equal(payslip.taxable, row["taxable"].to_i)
    assert_equal(payslip.ccf, row["ccf_tax"].to_i)
    assert_equal(payslip.cnps, row["cnps_tax"].to_i)
    assert_equal(payslip.proportional, row["prop_tax"].to_i)
    assert_equal(payslip.crtv, row["crtv_tax"].to_i)
    assert_equal(payslip.communal, row["comm_tax"].to_i)
    assert_equal(payslip.cac, row["cac_tax"].to_i)
    assert_equal(payslip.net_pay.to_f, row["net_sal"].to_f)
    assert_equal(payslip.department_cnps, row["dept_cnps"].to_i)
    assert_equal(payslip.department_credit_foncier, row["dept_cf"].to_i)
    assert_equal(payslip.employee_fund, row["emp_fund"].to_i)
  end

  test "a payslip with zero taxable pay (employee on leave) doesn't appear, even though the payslip itself exists" do
    employee = return_valid_employee
    jan = Period.new(2018, 1)
    generate_work_hours(employee, jan)
    employee.employment_status = "leave"
    payslip = Payslip.process(employee, jan)

    assert(payslip, "a payslip record should still exist for the on-leave month")
    assert_equal(0, payslip.taxable.to_i, "sanity check: on-leave payslips have no taxable pay")

    row = find_row(run_yearly_report("2018-1"), employee)
    refute(row, "the WHERE clause requires taxable > 0 (or vacation pay > 0), " +
        "so a year with only a zero-pay month is excluded from the report entirely")
  end

  test "taxable includes a vacation's gross pay, and its tax contribution is included too" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    # set_previous_vacation_balances also processes june (july.previous) --
    # since this report sums the WHOLE year, june's payslip contributes to
    # the total too, not just july/august.
    set_previous_vacation_balances(employee, july, 100000, 20.0)
    june_payslip = employee.payslip_for(july.previous)
    generate_work_hours_for_range(employee, july.start, Date.new(2018, 7, 23))

    vacation = Vacation.create!(employee: employee,
        start_date: "2018-07-24", end_date: "2018-08-18")
    assert_equal(Period.new(2018, 8), vacation.apply_to_period)

    july_payslip = Payslip.process(employee, july)
    generate_work_hours_for_range(employee, Date.new(2018, 8, 19), Period.new(2018, 8).finish)
    august_payslip = Payslip.process(employee, Period.new(2018, 8))

    vacation.reload
    assert(vacation.vacation_pay > 0, "vacation pay should have been computed while processing august")
    assert(vacation.ccf > 0, "vacation should have a nonzero ccf tax, to make this test discriminating")

    row = find_row(run_yearly_report("2018-7"), employee)
    assert(row)

    expected_taxable = june_payslip.taxable + july_payslip.taxable + august_payslip.taxable + vacation.vacation_pay
    assert_equal(expected_taxable, row["taxable"].to_i,
        "the year's taxable is all three months' taxable plus the vacation's gross pay")
    expected_ccf = june_payslip.ccf + july_payslip.ccf + august_payslip.ccf + vacation.ccf
    assert_equal(expected_ccf, row["ccf_tax"].to_i,
        "the year's ccf_tax includes all three months' ccf plus the vacation's own ccf")
  end

  test "two processed months in the same year collapse into a single row, unlike AnnualPayslipReport" do
    employee = return_valid_employee
    jan = Period.new(2018, 1)
    feb = Period.new(2018, 2)
    generate_work_hours(employee, jan)
    generate_work_hours(employee, feb)
    jan_payslip = Payslip.process(employee, jan)
    feb_payslip = Payslip.process(employee, feb)

    rows = run_yearly_report("2018-1").select { |r| r["employee_id"].to_i == employee.id }
    assert_equal(1, rows.length, "one row for the whole year, not one per month")
    assert_equal(jan_payslip.taxable + feb_payslip.taxable, rows.first["taxable"].to_i)
  end

  private

  def run_yearly_report(period_str)
    run_report(EmployeeYearlyReport, period_str)
  end

  def find_row(rows, employee)
    rows.find { |row| row["employee_id"].to_i == employee.id }
  end

end
