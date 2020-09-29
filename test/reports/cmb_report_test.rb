require "test_helper"

class CmbReportTests < ActiveSupport::TestCase

  test "Active Statuses" do
    exp = []
    exp.push(Employee.employment_statuses[:full_time])
    exp.push(Employee.employment_statuses[:part_time])
    exp.push(Employee.employment_statuses[:temporary])

    report = DipesReport.new(period: LastPostedPeriod.current.to_s)
    ary = report.employment_status()
    assert_equal(exp, ary, "It's all of them")
  end

end
