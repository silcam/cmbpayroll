require "test_helper"

# End-to-end coverage for EmployeeYearlyReport through its actual
# Thinreports view (app/views/reports/employee_yearly.pdf.thinreports),
# producing a real PDF. Mirrors annual_payslip_rendering_test.rb, but this
# report is one row per employee per YEAR (no monthly breakdown), so its
# positional bindings differ (taxable is t[4], not t[5]) and the footer
# totals sum across employees rather than across an employee's months.
#
# Verifies data BINDING, not visual layout (text extraction can't detect a
# column overflowing or overlapping) -- complements eyeballing the PDF.
#
# report_digits / report_body_and_footer live in test_helper.rb.
class EmployeeYearlyRenderingTest < ActiveSupport::TestCase

  test "renders a valid PDF for a processed payslip" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    pdf = render_report_pdf(EmployeeYearlyReport, "2018-7")

    assert(pdf.start_with?("%PDF"), "should produce a valid PDF document")
    assert(pdf.bytesize > 1000, "PDF should have real content, not be an empty shell")
  end

  test "the taxable column renders under the 'imposable' heading with the SQL taxable value" do
    employee = return_valid_employee
    employee.cnps = "CNPS123"
    employee.niu = "NIU456"
    employee.save!

    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    payslip = Payslip.process(employee, july)

    assert(payslip.taxable > 0, "sanity check: payslip should have nonzero taxable pay")

    text = report_pdf_text(render_report_pdf(EmployeeYearlyReport, "2018-7"))
    body, _footer = report_body_and_footer(text)

    # Match the header in a way that doesn't matter if it gets separated 
    # onto two lines or changes case via the "imposable" token, ignoring case. 
    assert_includes(text.downcase, "imposable", "the taxable column heading should render")

    # The employee's row should render, keyed by its identifiers...
    assert_includes(body, "NIU456")
    assert_includes(body, "CNPS123")

    # ...and the taxable figure should appear in the DETAIL row (not just
    # the totals) -- the point of the t[4] positional binding and the
    # add_row `taxable:` key lining up with the .tlf `taxable` item. Scoped
    # to the body so a mis-bound detail cell can't pass via the separately
    # accumulated totals row.
    #
    # NB: `body` also includes the header's report-year digits, so avoid
    # taxable values that look like a year to keep this a true match.
    assert_includes(report_digits(body), payslip.taxable.to_s,
        "the taxable value should render in the report body")
  end

  test "the taxable total accumulates across employees' yearly rows" do
    employee_a = return_valid_employee
    employee_b = return_valid_employee

    july = Period.new(2018, 7)
    generate_work_hours(employee_a, july)
    generate_work_hours(employee_b, july)
    payslip_a = Payslip.process(employee_a, july)
    payslip_b = Payslip.process(employee_b, july)

    expected_total = payslip_a.taxable + payslip_b.taxable
    assert(expected_total > 0, "sanity check: nonzero total")
    # Guard against a collision that would make the total test vacuous: the
    # footer sum must differ from either employee's own taxable, or a
    # broken accumulation could still match a detail value.
    refute_equal(payslip_a.taxable, expected_total)

    text = report_pdf_text(render_report_pdf(EmployeeYearlyReport, "2018-7"))
    _body, footer = report_body_and_footer(text)

    # One row per employee, then a Totals row summing across all of them --
    # exercises the @taxable_total accumulation. Scoped to the footer.
    refute_empty(footer, "the footer totals row should render")
    assert_includes(report_digits(footer), expected_total.to_s,
        "the taxable total should be the sum of both employees' taxable")
  end

end
