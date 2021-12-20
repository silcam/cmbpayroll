require "test_helper"

class JournalReportTest < ActiveSupport::TestCase

  test "Results from blank period doesn't Return nils" do
    report = JournalReport.new()
    period = LastPostedPeriod.current.next

    assert(report.produce_report(period),
        "this report, in a new period without data, should still run ok")
  end

end
