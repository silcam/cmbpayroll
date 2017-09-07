require "test_helper"

class PayslipTest < ActiveSupport::TestCase

  test "must be valid with correct attributes" do
    employee = return_valid_employee()

    assert(employee.valid?, "must be valid")
    refute_nil(employee.id, "employee ID cannot be nil")
    employee.save
    assert(employee.persisted?, "must be persisted")

    assert(employee.id >= 1, "Employee ID must exist and be non-zero")

    payslip = Payslip.new({
        payslip_date: "2017-07-31",
        period_start: "2017-08-01",
        period_end: "2017-08-31"
    })
    refute_nil(payslip)

    employee.payslips << payslip

    refute_nil(payslip.employee_id)

    create_earnings(payslip)

    refute_nil(payslip.employee)
    assert(payslip.valid?)
  end

  test "is not valid without an employee reference" do
    employee = return_valid_employee()

    payslip = Payslip.new
    payslip.payslip_date = "2017-07-31"
    payslip.period_start = "2017-08-01"
    payslip.period_end = "2017-08-31"

    create_earnings(payslip)

    value(payslip).wont_be :valid?

    payslip.employee = employee
    assert(payslip.valid?)
  end

  test "is not valid without payslip date" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()

    #payslip.payslip_date = "2017-07-31"
    payslip.period_start = "2017-08-01"
    payslip.period_end = "2017-08-31"

    create_earnings(payslip)

    refute(payslip.valid?)
    payslip.payslip_date = "2017-07-31"
    assert(payslip.valid?)
  end

  test "is not valid without period start" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()

    payslip.payslip_date = "2017-07-31"
    #payslip.period_start = "2017-08-01"
    payslip.period_end = "2017-08-31"

    create_earnings(payslip)

    refute(payslip.valid?)
    payslip.period_start = "2017-08-01"
    assert(payslip.valid?)
  end

  test "is not valid without period end" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_start = "2017-08-01"
    #payslip.period_end = "2017-08-31"

    create_earnings(payslip)

    refute(payslip.valid?)
    payslip.period_end = "2017-08-31"
    assert(payslip.valid?)
  end

  test "payslip is not valid without earnings" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_start = "2017-08-01"
    payslip.period_end = "2017-08-31"

    payslip.process()

    refute(payslip.valid?, "payslip should not be valid without earnings")
    refute(payslip.errors[:earnings].empty?, "yep, errors")

    create_earnings(payslip)

    assert(payslip.earnings.size == 1, "should have one earnings record")

    assert(payslip.valid?, "payship with earnings should be valid")
    assert(payslip.errors[:earnings].empty?, "no errors should be found")
  end

  test "last processed date should be generated" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_start = "2017-08-01"
    payslip.period_end = "2017-08-31"

    create_earnings(payslip)

    payslip.process()

    refute_nil(payslip.last_processed)
  end

  test "is valid with earnings records of 0" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_start = "2017-08-01"
    payslip.period_end = "2017-08-31"

    payslip.process()

    refute(payslip.valid?, "payslip should not be valid without earnings")
    refute(payslip.errors[:earnings].empty?, "yep, errors")

    create_earnings(payslip)

    assert(payslip.earnings.size == 1, "should have one earnings record")

    assert(payslip.valid?, "payship with earnings should be valid")
    assert(payslip.errors[:earnings].empty?, "no errors should be found")
  end

  test "earning computation is correct" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_start = "2017-08-01"
    payslip.period_end = "2017-08-31"

    earning_base = Earning.new

    earning_base.hours = 8
    earning_base.rate = 1000
    earning_base.description = "Base Hours"

    payslip.earnings << earning_base

    earning_overtime = Earning.new

    earning_overtime.hours = 3
    earning_overtime.rate = 1500
    earning_overtime.description = "Overtime Hours"

    payslip.earnings << earning_overtime

    assert(payslip.earnings.size == 2, "should have two earnings records")

    payslip.process()
    assert_equal(12500, payslip.total_earnings())

  end


  test "work hours become earnings" do
    employee = return_valid_employee()

    hours = {'2017-08-01' => 8,
             '2017-08-02' => 6,
             '2017-08-03' => 3.5,
             '2017-08-04' => 2,
             '2017-08-05' => 1,
             '2017-08-06' => 1.2}

    WorkHour.update employee, hours

    ### verify hours
    exp = {:normal => 171.5, :overtime => 2.2}
    assert_equal exp, WorkHour.total_hours(employee, Period.new(2017, 8))

    payslip = Payslip.process(employee, Period.new(2017,8))

    payslip.earnings.all do |record|
        # verify hours in earning records
        if (record.overtime == true)
            assert_equal(2.2, record.hours)
        else
            assert_equal(171.5, record.hours)
        end
    end
  end

end
