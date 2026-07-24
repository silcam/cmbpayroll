require "test_helper"

class EmployeeVacationReportTest < ActiveSupport::TestCase

  test "a period with no processed payslips returns no rows without erroring" do
    rows = run_employee_vacation_report("2018-1")
    assert_equal([], rows, "no payslips were processed in this period")
  end

  test "a processed payslip appears in the report for its own period, with balances matching the payslip record" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    set_previous_vacation_balances(employee, july, 100000, 20.0)
    generate_work_hours(employee, july)
    payslip = Payslip.process(employee, july)

    rows = run_employee_vacation_report("2018-7")
    row = find_employee_row(rows, employee)

    assert(row, "the employee's july payslip should show up in july's report")

    # Guard against these all being trivially nil/0 on both sides, which
    # would make the equality checks below pass vacuously.
    assert(payslip.vacation_balance.to_f > 0, "sanity check: payslip should have a nonzero balance")
    assert(payslip.vacation_pay_earned.to_i > 0, "sanity check: payslip should have nonzero pay earned")
    assert(payslip.vacation_earned.to_f > 0, "sanity check: payslip should have nonzero days earned")

    assert_equal(payslip.vacation_balance.to_f, row["vacation_balance"].to_f)
    assert_equal(payslip.vacation_pay_earned, row["vacation_pay_earned"].to_i)
    assert_equal(payslip.vacation_earned.to_f, row["vacation_earned"].to_f)
  end

  test "an employee with a payslip in a different period doesn't appear -- the LEFT JOIN is filtered down to an inner join by the WHERE clause" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    set_previous_vacation_balances(employee, july, 100000, 20.0)
    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    # July has a payslip, august doesn't -- despite the LEFT JOIN, the
    # ps.period_month/ps.period_year filters in the WHERE clause mean a
    # missing payslip drops the employee from the report entirely, rather
    # than showing up with null balances.
    august_rows = run_employee_vacation_report("2018-8")
    refute(find_employee_row(august_rows, employee),
        "no payslip exists for august, so the employee shouldn't appear")

    july_rows = run_employee_vacation_report("2018-7")
    assert(find_employee_row(july_rows, employee),
        "july's own payslip should still show up in july's report")
  end

  test "last_vacation_end reflects the last vacation completed before the payslip's period" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    set_previous_vacation_balances(employee, july, 100000, 20.0)

    vacation = Vacation.create!(employee: employee,
        start_date: "2018-06-04", end_date: "2018-06-08")

    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    rows = run_employee_vacation_report("2018-7")
    row = find_employee_row(rows, employee)

    assert(row)
    assert_equal(vacation.end_date.to_s, row["last_vacation_end"])
  end

  private

  def run_employee_vacation_report(period_str)
    run_report(EmployeeVacationReport, period_str)
  end

  def find_employee_row(rows, employee)
    rows.find { |row| row["id"].to_i == employee.id }
  end

end
