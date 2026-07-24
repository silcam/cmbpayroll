require "test_helper"

class CmbReportTests < ActiveSupport::TestCase

  test "All Statuses" do
    exp = []
    exp.push(Employee.employment_statuses[:full_time])
    exp.push(Employee.employment_statuses[:part_time])
    exp.push(Employee.employment_statuses[:temporary])
    exp.push(Employee.employment_statuses[:leave])
    exp.push(Employee.employment_statuses[:terminated_to_year_end])
    exp.push(Employee.employment_statuses[:inactive])

    report = DipesReport.new(period: LastPostedPeriod.current.to_s)
    ary = report.employment_status()
    assert_equal(exp, ary, "It's all of them")
  end

end
