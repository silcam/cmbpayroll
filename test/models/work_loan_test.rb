require "test_helper"

class WorkLoanTest < ActiveSupport::TestCase
  def setup
    @luke = employees :Luke
    @admin = departments :Admin
    @lss = departments :LSS
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test WorkLoan, some_valid_params
  end

  test "WorkLoans don't increase WorkHours totals" do
    period = Period.new(2017,8)
    employee = return_valid_employee()
    generate_work_hours employee, period

    assert_equal(184, WorkHour.total_hours(employee, period)[:normal])

    create_and_assign_loan(employee, period, 3, @admin)
    create_and_assign_loan(employee, period, 3, @admin)

    hours = {'2017-08-31'=>'13'}
    WorkHour.update employee, hours, {}

    assert_equal(184, WorkHour.total_hours(employee, period)[:normal])
    assert_equal(5.0, WorkHour.total_hours(employee, period)[:overtime])
  end

  test "WorkLoans for_period" do
    employee1 = return_valid_employee()
    employee2 = return_valid_employee()

    period = Period.new(2017,8)

    # This period
    create_and_assign_loan(employee1, period, 1, @admin)

    # Next period #1
    create_and_assign_loan(employee2, period.next, 2, @admin)

    # Next period #2
    create_and_assign_loan(employee1, period.next, 3, @admin)

    current_period_loans = WorkLoan.for_period(period)
    assert_equal(1, current_period_loans.size)
    assert_equal(1, current_period_loans.first.hours)

    next_period_loans = WorkLoan.for_period(period.next)
    assert_equal(2, next_period_loans.size)

    previous_period_loans = WorkLoan.for_period(period.previous)
    assert_equal(0, previous_period_loans.size)
  end

  test "Can Sum Work Loans for periods" do
    period = Period.new(2017,8)

    employee1 = return_valid_employee()
    employee2 = return_valid_employee()
    generate_work_hours employee1, period
    generate_work_hours employee2, period

    # This period
    create_and_assign_loan(employee1, period, 3, @admin)
    create_and_assign_loan(employee2, period, 4, @admin)

    # Next period
    create_and_assign_loan(employee1, period.next, 5, @lss)
    create_and_assign_loan(employee1, period.next, 2, @admin)
    create_and_assign_loan(employee2, period.next, 4, @admin)

    #Total Hours per Period per employee
    assert_equal(3, WorkLoan.total_hours(employee1, period))
    assert_equal(4, WorkLoan.total_hours(employee2, period))
    assert_equal(7, WorkLoan.total_hours(employee1, period.next))
    assert_equal(4, WorkLoan.total_hours(employee2, period.next))

    # total Hours for Periods
    assert_equal(7, WorkLoan.total_hours_for_period(period))
    assert_equal(11, WorkLoan.total_hours_for_period(period.next))

    #Total Hours per Period per Employee per Department
    assert_equal({ "Admin" => 7 }, WorkLoan.total_hours_per_department(period))
    assert_equal({ "Admin" => 6, "LSS" => 5 }, WorkLoan.total_hours_per_department(period.next))

    refute(WorkLoan.has_hours_for_period?(period.previous))
    assert(WorkLoan.has_hours_for_period?(period))
  end

  def some_valid_params
    {employee: @luke, date: '2017-08-09', hours: 9, department_person: @admin.name}
  end

  def create_and_assign_loan(employee, period, hours, department = nil)
    work_loan = WorkLoan.new

    work_loan.date = period.start
    work_loan.hours = hours
    work_loan.department_person = department.name

    employee.work_loans << work_loan
    work_loan
  end
end
