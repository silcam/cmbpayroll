require "test_helper"

# End-to-end coverage for AnnualPayslipReport that goes through the actual
# Thinreports view (app/views/reports/annual_payslip.pdf.thinreports) and
# produces a real PDF. This exercises the layer the SQL-level integration
# tests skip: the positional column bindings (t[5] -> taxable, etc.), the
# add_row keys matching the .tlf item ids, number formatting, the running
# totals, and per-employee page breaks.
#
# It verifies data BINDING correctness, not visual layout -- text
# extraction can't detect a column running off the page or overlapping.
# So this complements, but does not replace, eyeballing the generated PDF.
class AnnualPayslipRenderingTest < ActiveSupport::TestCase

  # report_digits / report_body_and_footer live in test_helper.rb (shared
  # with the other report e2e tests).

  test "renders a valid PDF for a processed payslip" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    pdf = render_report_pdf(AnnualPayslipReport, "2018-7")

    assert(pdf.start_with?("%PDF"), "should produce a valid PDF document")
    assert(pdf.bytesize > 1000, "PDF should have real content, not be an empty shell")
  end

  test "the taxable column renders under the 'Imposable' heading with the SQL taxable value" do
    employee = return_valid_employee
    employee.cnps = "CNPS123"
    employee.niu = "NIU456"
    employee.save!

    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    payslip = Payslip.process(employee, july)

    assert(payslip.taxable > 0, "sanity check: payslip should have nonzero taxable pay")

    text = report_pdf_text(render_report_pdf(AnnualPayslipReport, "2018-7"))
    body, _footer = report_body_and_footer(text)

    # The .tlf column heading is "Salaire" / "Imposable" on two lines;
    # "Imposable" is the distinctive token.
    assert_includes(text, "Imposable", "the taxable column heading should render")

    # The employee's row should render, keyed by its identifiers...
    assert_includes(body, "NIU456")
    assert_includes(body, "CNPS123")

    # ...and the taxable figure should appear in the DETAIL row (not just
    # the totals) -- this is the point of the t[5] positional binding and
    # the add_row `taxable:` key lining up with the .tlf `taxable` item.
    # Scoped to the body so a mis-bound detail cell can't pass via the
    # separately-accumulated totals row.
    #
    # NB: `body` also includes the header's report-year and generated date
    # digits, so avoid taxable values that look like a year (e.g. 2018) to
    # keep this a true match on the rendered figure.
    assert_includes(report_digits(body), payslip.taxable.to_s,
        "the taxable value should render in the report body")
  end

  test "the taxable total accumulates across an employee's monthly rows" do
    employee = return_valid_employee
    jan = Period.new(2018, 1)
    feb = Period.new(2018, 2)
    generate_work_hours(employee, jan)
    generate_work_hours(employee, feb)
    jan_payslip = Payslip.process(employee, jan)
    feb_payslip = Payslip.process(employee, feb)

    expected_total = jan_payslip.taxable + feb_payslip.taxable
    assert(expected_total > 0, "sanity check: nonzero total")

    text = report_pdf_text(render_report_pdf(AnnualPayslipReport, "2018-1"))
    _body, footer = report_body_and_footer(text)

    # Two monthly rows, then a Totals row summing them -- exercises the
    # @taxable_total accumulation in the view. Scoped to the footer.
    refute_empty(footer, "the footer totals row should render")
    assert_includes(report_digits(footer), expected_total.to_s,
        "the taxable total should be the sum of both months' taxable")
  end

  test "a department CNPS total over 1,000,000 renders in full, not clipped to fit the column" do
    # Regression guard for the production display bug: a 7-digit total (a
    # dept CNPS annual total crossing 1,000,000) is silently clipped by the
    # fixed-width, overflow:truncate total cell -- e.g. 1,000,333 shown as
    # "1 000". Monthly figures fit the column; only the summed total spills.
    #
    # This checks the number isn't string-truncated. It does NOT verify
    # visual layout: text extraction can't see a widened cell overlapping
    # its neighbour, so the .tlf column widths still need an eyeball.
    employee = return_valid_employee

    # Two months whose department_cnps each fit the column but sum past a
    # million. The total is deliberately NON-round (...333): report_digits
    # strips separators, so a round total clipped to "1 000" could be
    # reconstructed from the zero-valued neighbouring columns ("1 000" +
    # "0 0 0" -> "1000000"). A non-round tail can't be, so the assertion
    # only passes when the whole number actually renders.
    [[Period.new(2018, 3), 500_111], [Period.new(2018, 5), 500_222]].each do |period, dept_cnps|
      generate_work_hours(employee, period)
      Payslip.process(employee, period).update_columns(department_cnps: dept_cnps)
    end
    expected_total = 500_111 + 500_222 # 1,000,333
    assert(expected_total > 1_000_000, "sanity: total must cross the million that overflows the cell")

    text = report_pdf_text(render_report_pdf(AnnualPayslipReport, "2018-1"))
    _body, footer = report_body_and_footer(text)

    assert_includes(report_digits(footer), expected_total.to_s,
        "the full department CNPS total should render in the footer, not be clipped")
  end

end
