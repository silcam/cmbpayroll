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

  # Reduce a chunk of extracted PDF text to just its digits, so a rendered
  # figure can be matched regardless of the thousands-separator/locale
  # formatting thinreports emits (e.g. "87 890" -> "87890").
  def digits(text)
    text.gsub(/\D/, "")
  end

  # The footer row is marked by the literal "Totals:" label, so partition
  # on it to tell the detail rows (body) apart from the accumulated totals
  # (footer). This matters: the totals accumulate x_taxable independently
  # of what the detail cell binds, so asserting a value against the whole
  # document would still pass even if the detail cell were mis-bound.
  def body_and_footer(text)
    before, _sep, after = text.partition("Totals:")
    [before, after]
  end

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
    body, _footer = body_and_footer(text)

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
    assert_includes(digits(body), payslip.taxable.to_s,
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
    _body, footer = body_and_footer(text)

    # Two monthly rows, then a Totals row summing them -- exercises the
    # @taxable_total accumulation in the view. Scoped to the footer.
    refute_empty(footer, "the footer totals row should render")
    assert_includes(digits(footer), expected_total.to_s,
        "the taxable total should be the sum of both months' taxable")
  end

end
