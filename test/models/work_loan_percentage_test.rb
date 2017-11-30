require "test_helper"

class WorkLoanPercentageTest < ActiveSupport::TestCase

  test "create object" do
    employee = return_valid_employee()
    admin_dept = departments :Admin
    ps = Payslip.new

    ps.period_year = 2018
    ps.period_month = 1

    lp = WorkLoanPercentage.new

    ps.work_loan_percentages << lp

    lp.department_id = admin_dept.id
    lp.percentage = "0.2345"

    assert(lp.valid?, "should be valid")
  end

end
