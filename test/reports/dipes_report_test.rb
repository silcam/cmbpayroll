require "test_helper"

class DipesReportTest < ActiveSupport::TestCase

  test "Test" do
    report = DipesReport.new(period: LastPostedPeriod.current.to_s)
    assert(report.results.hashes)
  end

end
