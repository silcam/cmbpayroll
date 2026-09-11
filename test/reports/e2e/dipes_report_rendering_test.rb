require "test_helper"

# End-to-end coverage for the DIPE filing, which is the only report that
# renders as fixed-width text rather than a PDF. Every money field is
# declared :numeric and lib/fixy/formatter/numeric.rb enforces /^\d+$/, so
# the record either builds or raises -- there is no partially-wrong output
# to inspect, which makes generating it the whole test.
#
# render_report_txt goes through exec_query, so the columns arrive decoded
# exactly as they do in a real request.
class DipesReportRenderingTest < ActiveSupport::TestCase

  setup do
    @employee = return_valid_employee
    @employee.cnps = "12345678901"
    @employee.save!

    @july = Period.new(2018, 7)
    generate_work_hours(@employee, @july)
    @payslip = Payslip.process(@employee, @july)
  end

  test "generates the fixed-width file" do
    txt = render_report_txt(DipesReport, "2018-7")

    assert(@payslip.taxable > 0, "sanity check: the row only appears if taxable > 0")

    lines = txt.split("\r\n")
    assert_equal(1, lines.size, "one employee was processed, so one record")
    assert_equal(194, lines.first.length, "the record length Fixy declares")
    assert(txt.start_with?("C04"), "the DIPE record type")
  end

  test "renders the salary columns as whole digits, not a decimal" do
    txt = render_report_txt(DipesReport, "2018-7")

    # ROUND(...,0) makes these numeric, which 6.1 decodes to BigDecimal;
    # its to_s is "581895.0" under ActiveSupport's "F" default, and the
    # :numeric formatter rejects anything but digits. Assert on the field
    # positions rather than the whole line so a stray "." elsewhere can't
    # stand in for the thing being checked.
    salaire_brut = txt[54, 10]
    salaire_taxable = txt[74, 10]

    assert_match(/\A *\d+\z/, salaire_brut, "salaire_brut should be whole digits")
    assert_match(/\A *\d+\z/, salaire_taxable, "salaire_taxable should be whole digits")
    assert_equal(@payslip.taxable.round, salaire_brut.strip.to_i)
  end

  test "format_salbrut rounds the decoded BigDecimal to an Integer" do
    report = DipesReport.new(period: "2018-7")

    assert_equal(581_895, report.format_salbrut(BigDecimal("581895")))
    assert_instance_of(Integer, report.format_salbrut(BigDecimal("581895")))
    assert_nil(report.format_salbrut(nil))
  end

end
