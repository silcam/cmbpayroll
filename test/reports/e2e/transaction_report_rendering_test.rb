require "test_helper"

# End-to-end coverage for both transaction audit reports through their
# Thinreports views, producing real PDFs.
#
# The point of rendering these (rather than only unit-testing format_date)
# is that render_report_pdf goes through exec_query and the dossier result
# adapter, so the date column arrives decoded exactly as it does in a real
# request. The unit tests hand format_date a Time on the assumption that
# that is what the adapter produces; these prove the assumption.
#
# Verifies data BINDING, not visual layout -- complements eyeballing the PDF.
class TransactionReportRenderingTest < ActiveSupport::TestCase

  CHARGE_DATE = "2018-07-10".freeze

  setup do
    @employee = return_valid_employee
    @july = Period.new(2018, 7)

    # Processing on its own produces nothing the report will show: "Monthly
    # Wages" is in the SELECT's excluded-description list and the OT rows
    # come out at zero, which the amount > 0 filter drops. A charge becomes
    # a deduction on the payslip and is the simplest row that survives.
    Charge.create!(employee: @employee, amount: 4321, charge_type: :advance,
        date: CHARGE_DATE, note: "Phone")

    generate_work_hours(@employee, @july)
    Payslip.process(@employee, @july)
  end

  [TransactionReportByType, TransactionReportByName].each do |report_class|
    test "#{report_class} renders a valid PDF" do
      pdf = render_report_pdf(report_class, "2018-7")

      assert(pdf.start_with?("%PDF"), "should produce a valid PDF document")
      assert(pdf.bytesize > 1000, "PDF should have real content, not be an empty shell")
    end

    test "#{report_class} renders the transaction date as a bare date" do
      text = report_pdf_text(render_report_pdf(report_class, "2018-7"))
      body, _footer = report_body_and_footer(text)

      # Sanity check: the date assertions below are all about what the row
      # renders, so they would pass on an empty report.
      assert_includes(body, "Phone", "the charge's deduction row should render")

      # The view binds t[3].to_s straight into the cell, so a format_date
      # that handed back the decoded value unchanged would render the whole
      # timestamp -- "2018-07-10 00:00:00 UTC" -- rather than a date. Both
      # halves matter: the date has to be there, and the time must not be.
      assert_includes(body, CHARGE_DATE,
          "the transaction date column should render the charge's date")
      refute_match(/\d{2}:\d{2}:\d{2}/, body,
          "the date column should not carry the timestamp's time part")
      refute_includes(body, "UTC",
          "the date column should not carry the decoded Time's zone")
    end
  end

end
