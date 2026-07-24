require "test_helper"

class VacationReportTest < ActiveSupport::TestCase

  test "a period with no paid-out vacations returns no rows without erroring" do
    rows = run_vacation_report("2018-1")
    assert_equal([], rows, "no vacations were paid out in this period")
  end

  test "a paid vacation appears in the report for its own period, with totals matching the vacation record" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    set_previous_vacation_balances(employee, july, 100000, 20.0)
    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    vacation = Vacation.create!(employee: employee,
        start_date: "2018-07-09", end_date: "2018-07-13")
    vacation.mark_paid
    vacation.save!

    rows = run_vacation_report("2018-7")
    row = find_employee_row(rows, employee)

    assert(row, "the employee's paid vacation should show up in july's report")
    assert_equal(vacation.vacation_pay, row["gross_pay"].to_i)
    assert_equal(vacation.vacation_pay - vacation.total_tax, row["net_pay"].to_i)
    assert_equal(vacation.total_tax, row["total_tax"].to_i)
  end

  test "a vacation spanning two months is reported under its applied period, not the month it starts in" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    set_previous_vacation_balances(employee, july, 100000, 20.0)
    generate_work_hours_for_range(employee, july.start, Date.new(2018, 7, 23))

    # More days fall in august than july, so apply_to_period is august --
    # even though the vacation starts in july.
    vacation = Vacation.create!(employee: employee,
        start_date: "2018-07-24", end_date: "2018-08-18")
    assert_equal(Period.new(2018, 8), vacation.apply_to_period)
    vacation.mark_paid
    vacation.save!

    july_rows = run_vacation_report("2018-7")
    refute(find_employee_row(july_rows, employee),
        "the vacation isn't attributed to july, even though it starts there")

    august_rows = run_vacation_report("2018-8")
    assert(find_employee_row(august_rows, employee),
        "the vacation should show up in the period it's attributed to")
  end

  test "a locked vacation's reported totals don't drift after a raise reprocesses its still-open applied period" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    set_previous_vacation_balances(employee, july, 100000, 20.0)
    generate_work_hours_for_range(employee, july.start, Date.new(2018, 7, 23))

    # Spans a month boundary, with more days in august -- apply_to_period is
    # august, but the vacation starts (and gets processed/posted) in july.
    # Mirrors the regression scenario in vacation_test.rb.
    vacation = Vacation.create!(employee: employee,
        start_date: "2018-07-24", end_date: "2018-08-18")
    assert_equal(Period.new(2018, 8), vacation.apply_to_period)

    Payslip.process(employee, july)

    # Close (post) july only -- august stays open.
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update(year: 2018, month: 7)
    lpp.save!

    # Stay before the vacation's start date throughout, so the "start date
    # has passed" backstop can't be what locks this -- isolating the
    # period-posted lock, which is what's actually being exercised here.
    Date.stub :today, Date.new(2018, 7, 1) do
      # Payslip.process only auto-computes a vacation's pay for the period
      # it's ultimately attributed to (here, august) -- so trigger it
      # explicitly from july's payslip, same as prep_print/mark_paid would
      # before the vacation starts.
      original_pay = vacation.vacation_pay
      assert(original_pay > 0, "vacation pay should be computed from july's payslip")

      original_row = find_employee_row(run_vacation_report("2018-8"), employee)
      assert(original_row, "vacation pay should already be computed from july's payslip")
      original_gross = original_row["gross_pay"].to_i

      # Grant a raise and actually reprocess august for real -- since august
      # was never posted, nothing here should be able to touch this vacation.
      employee.echelon = "a"
      employee.save!
      generate_work_hours_for_range(employee, Date.new(2018, 8, 19), Period.new(2018, 8).finish)
      Payslip.process(employee, Period.new(2018, 8))

      updated_row = find_employee_row(run_vacation_report("2018-8"), employee)
      assert_equal(original_gross, updated_row["gross_pay"].to_i,
          "the report should reflect the vacation's locked total, not a post-raise " +
            "recompute of the still-open period its pay happens to be attributed to")
    end
  end

  private

  def run_vacation_report(period_str)
    run_report(VacationReport, period_str)
  end

  def find_employee_row(rows, employee)
    rows.find { |row| row["id"].to_i == employee.id }
  end

end
