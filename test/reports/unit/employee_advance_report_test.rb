require "test_helper"

class EmployeeAdvanceLoanReportTest < ActiveSupport::TestCase

  test "Test" do

    report = EmployeeAdvanceLoanReport.new

    report.options[:period] = "2017-2"

    assert_equal("2017-02-01", report.start.to_s)
    assert_equal("2017-02-28", report.finish.to_s)

    report.options[:period] = "2017-7"

    assert_equal("2017-07-01", report.start.to_s)
    assert_equal("2017-07-31", report.finish.to_s)

    report.options[:period] = "2017-9"

    assert_equal("2017-09-01", report.start.to_s)
    assert_equal("2017-09-30", report.finish.to_s)

    report.options[:period] = "2016-2" # leap year

    assert_equal("2016-02-01", report.start.to_s)
    assert_equal("2016-02-29", report.finish.to_s)

    report.options[:period] = "2017-12" # year boundary

    assert_equal("2017-12-01", report.start.to_s)
    assert_equal("2017-12-31", report.finish.to_s)

  end

end
