require "test_helper"

# A smoke test across every report the reports menu offers: build one
# employee's worth of ordinary data, then render each report end to end and
# assert it produced a document.
#
# This is deliberately shallow. It asserts nothing about the figures -- the
# per-report tests do that -- and its whole job is to prove each report
# still LOADS. Both 6.1 decoder regressions (timestamp on the transaction
# reports, numeric on the DIPE filing) were crashes on the render path with
# nothing in the suite walking it, so each was found by hand during manual
# validation instead of by a test.
#
# It iterates ReportsController::REPORTS rather than listing the classes,
# so adding a report to the menu adds it here automatically.
class AllReportsRenderingTest < ActiveSupport::TestCase

  PERIOD = Period.new(2018, 7)
  PERIOD_STR = "2018-7".freeze

  # The setup is built up rather than minimised: a report with no rows still
  # renders, so it would pass this file without its row-binding code ever
  # running. Each piece below exists to put a row into a report that the
  # piece before it left empty.
  setup do
    @employee = return_valid_employee
    # Several reports select or filter on these; blank is valid for them, so
    # leaving them unset renders a report that never exercises the columns.
    @employee.cnps = "12345678901"
    @employee.niu = "NIU456"
    @employee.save!

    # A charge becomes a deduction, which is the only row the transaction
    # reports will show -- processing alone produces nothing they don't
    # filter out.
    Charge.create!(employee: @employee, amount: 4321, charge_type: :advance,
        date: "2018-07-10", note: "Phone")

    set_previous_vacation_balances(@employee, PERIOD, 100_000, 20.0)
    generate_work_hours(@employee, PERIOD)
    @payslip = Payslip.process(@employee, PERIOD)

    # ...gives the vacation report its row, which needs a PAID vacation
    # rather than just an accrued balance.
    @vacation = Vacation.create!(employee: @employee,
        start_date: "2018-07-09", end_date: "2018-07-13")
    @vacation.mark_paid
    @vacation.save!

    # A second employee, at a different location and with a mid-year
    # echelon change. Between them those two facts are what put rows in
    # pay_breakdown_rfis (return_valid_employee is nonrfis) and in
    # salary_changes, which joins each payslip against the previous
    # period's and reports only where the category or echelon differs.
    @rfis_employee = return_valid_employee
    @rfis_employee.location = "rfis"
    @rfis_employee.echelon_c!

    generate_work_hours(@rfis_employee, PERIOD.previous)
    Payslip.process(@rfis_employee, PERIOD.previous)

    @rfis_employee.echelon_d!
    generate_work_hours(@rfis_employee, PERIOD)
    Payslip.process(@rfis_employee, PERIOD)
  end

  ReportsController::REPORTS.each do |key, config|
    test "#{key} renders" do
      report_class = config[:instance].call(nil).class

      if config[:format] == :pdf
        document = render_report_pdf(report_class, PERIOD_STR)

        assert(document.start_with?("%PDF"),
            "#{key} should produce a valid PDF document")
      else
        document = render_report_txt(report_class, PERIOD_STR)
      end

      assert(document.present?, "#{key} should produce a document")
    end
  end

  # The setup is the premise of every test above: a report with no rows
  # renders a valid, empty document, so if the fixtures stop producing data
  # this whole file keeps passing while proving nothing. Rather than assert
  # that report by report, check here that every one of them has rows.
  test "every report has rows to render" do
    assert(@payslip.taxable > 0, "the payslip should have taxable pay")

    empty = ReportsController::REPORTS.reject { |_key, config|
      run_report(config[:instance].call(nil).class, PERIOD_STR).any?
    }.keys

    assert_empty(empty, "these reports rendered with no rows, so their row " \
        "binding never ran -- give the setup whatever they select on")
  end

end
