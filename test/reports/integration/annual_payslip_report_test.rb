require "test_helper"

class AnnualPayslipReportTest < ActiveSupport::TestCase

  # A rough guide for reading a failure here after changing this report:
  # - Likely to change by design, if your work touches grouping/period
  #   granularity/who-appears: "the report groups by year only" (month
  #   ignored), "zero taxable pay ... doesn't appear" (the WHERE clause),
  #   "two different months ... two separate rows".
  # - Closer to real invariants: "empty year", "totals matching the
  #   payslip record", and the vacation-bucketing test -- though the
  #   latter can legitimately move if you rework the vacation join.
  #
  # Case in point: the "salaire_net" column was replaced with "taxable"
  # (COALESCE(SUM(ps.taxable),0) + COALESCE(SUM(v.vacation_pay),0) -- the
  # employee's total pay, i.e. payslip taxable plus a vacation's own gross
  # pay, matching VacationReport's gross_pay, but without the old
  # column's total_tax subtraction) and relabeled "Salaire imposable" in
  # annual_payslip.tlf. That's exactly why the "totals matching the
  # payslip record" and vacation-bucketing tests below needed updating --
  # they're pinned to specific column semantics, not just structure.

  # Important Note: these style of tests only test the Dossier-level SQL
  # that builds the report and not the output-formatting of the Thinreports
  # layer. That layer could add additional formatting, summing and totaling
  # which is not tested here.

  test "an empty year returns no rows without erroring" do
    rows = run_annual_payslip_report("2018-1")
    assert_equal([], rows, "no payslips were processed in this year")
  end

  test "a processed payslip appears as its own year/month row, with totals matching the payslip record" do
    employee = return_valid_employee
    employee.cnps = "CNPS123"
    employee.niu = "NIU456"
    employee.save!

    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    payslip = Payslip.process(employee, july)

    row = find_row(run_annual_payslip_report("2018-7"), employee, 7)

    assert(row, "july's processed payslip should show up as its own row")
    assert_equal(2018, row["py"].to_i)
    assert_equal(7, row["pm"].to_i)
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
    # net_sal is summed without a ROUND in the SQL (unlike salaire_net
    # above), so compare as floats rather than truncating with .to_i.
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

    row = find_row(run_annual_payslip_report("2018-1"), employee, 1)
    refute(row, "the WHERE clause requires taxable > 0 (or vacation pay > 0), " +
        "so a zero-pay month is excluded from the report entirely")
  end

  test "taxable includes a vacation's gross pay bucketed under its attributed month, and its tax contribution lands there too" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    set_previous_vacation_balances(employee, july, 100000, 20.0)
    generate_work_hours_for_range(employee, july.start, Date.new(2018, 7, 23))

    # More days fall in august, so apply_to_period is august.
    vacation = Vacation.create!(employee: employee,
        start_date: "2018-07-24", end_date: "2018-08-18")
    assert_equal(Period.new(2018, 8), vacation.apply_to_period)

    july_payslip = Payslip.process(employee, july)
    generate_work_hours_for_range(employee, Date.new(2018, 8, 19), Period.new(2018, 8).finish)
    # Processing august's own payslip is what triggers this vacation's pay
    # computation (Payslip.update_vacation_balances only calls vacation_pay
    # for vacations whose apply_to_period matches the payslip being
    # processed) -- and the vacation/payslip join below requires an actual
    # payslip row for that (year, month) to join against in the first place.
    august_payslip = Payslip.process(employee, Period.new(2018, 8))

    vacation.reload
    assert(vacation.vacation_pay > 0, "vacation pay should have been computed while processing august")
    assert(vacation.ccf > 0, "vacation should have a nonzero ccf tax, to make this test discriminating")

    rows = run_annual_payslip_report("2018-7")
    july_row = find_row(rows, employee, 7)
    august_row = find_row(rows, employee, 8)

    assert(july_row, "july has its own processed payslip")
    assert(august_row, "august has its own processed payslip")

    # taxable is now ps.taxable + v.vacation_pay -- july has no vacation
    # attributed to it, but august's row should include the vacation's
    # gross pay (matching VacationReport's gross_pay), on top of its own
    # payslip's taxable.
    assert_equal(july_payslip.taxable, july_row["taxable"].to_i,
        "july's taxable shouldn't include a vacation attributed to august")
    assert_equal(august_payslip.taxable + vacation.vacation_pay, august_row["taxable"].to_i,
        "august's taxable should include the vacation's gross pay attributed to it")

    # ccf_tax (COALESCE(SUM(ps.ccf),0) + COALESCE(SUM(v.ccf),0)) is
    # unaffected by this change, so the vacation's own tax contribution
    # should still land under the month it's attributed to.
    assert_equal(july_payslip.ccf, july_row["ccf_tax"].to_i,
        "july's ccf_tax shouldn't include a vacation attributed to august")
    assert_equal(august_payslip.ccf + vacation.ccf, august_row["ccf_tax"].to_i,
        "august's ccf_tax should include the vacation's own ccf, since it's attributed there")
  end

  test "an employee processed in two different months of the same year gets two separate rows" do
    employee = return_valid_employee
    jan = Period.new(2018, 1)
    feb = Period.new(2018, 2)
    generate_work_hours(employee, jan)
    generate_work_hours(employee, feb)
    Payslip.process(employee, jan)
    Payslip.process(employee, feb)

    rows = run_annual_payslip_report("2018-1").select { |r| r["employee_id"].to_i == employee.id }
    assert_equal([1, 2], rows.map { |r| r["pm"].to_i }.sort,
        "one row per processed month, not collapsed into a single yearly total")
  end

  test "the report groups by year only -- the period option's month component is ignored" do
    employee = return_valid_employee
    jan = Period.new(2018, 1)
    generate_work_hours(employee, jan)
    Payslip.process(employee, jan)

    rows_queried_via_january = run_annual_payslip_report("2018-1")
    rows_queried_via_december = run_annual_payslip_report("2018-12")

    refute_empty(rows_queried_via_january, "sanity check: shouldn't compare two empty results")
    assert_equal(rows_queried_via_january, rows_queried_via_december,
        "querying with any month in 2018 should return the same whole-year rows")
  end

  private

  def run_annual_payslip_report(period_str)
    run_report(AnnualPayslipReport, period_str)
  end

  def find_row(rows, employee, month)
    rows.find { |row| row["employee_id"].to_i == employee.id && row["pm"].to_i == month }
  end

end
