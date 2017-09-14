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
        period_year: Period.current.year,
        period_month: Period.current.month
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
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

    create_earnings(payslip)

    value(payslip).wont_be :valid?

    payslip.employee = employee
    assert(payslip.valid?)
  end

  test "is not valid without payslip date" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()

    #payslip.payslip_date = "2017-07-31"
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

    create_earnings(payslip)

    refute(payslip.valid?)
    payslip.payslip_date = "2017-07-31"
    assert(payslip.valid?)
  end

  test "is not valid without period start" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()

    payslip.payslip_date = "2017-07-31"
    #payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

    create_earnings(payslip)

    refute(payslip.valid?)
    payslip.period_year = Period.current.year
    assert(payslip.valid?)
  end

  test "is not valid without period end" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_year = Period.current.year
    #payslip.period_month = Period.current.month

    create_earnings(payslip)

    refute(payslip.valid?)
    payslip.period_month = Period.current.month
    assert(payslip.valid?)
  end

  test "payslip is not valid without earnings" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

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
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

    create_earnings(payslip)

    payslip.process()

    refute_nil(payslip.last_processed)
  end

  test "is valid with earnings records of 0" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

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
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

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

  test "bonuses become become earnings" do
    employee = return_valid_employee()
    employee.wage = 100
    assert employee.valid?


    # create bonuses

    bonus = Bonus.new
    bonus.name = "First Bonus"
    bonus.quantity = 12.0
    bonus.bonus_type = "percentage"
    assert bonus.valid?
    bonus.save

    bonus2 = Bonus.new
    bonus2.name = "Second Bonus"
    bonus2.quantity = 3000
    bonus2.bonus_type = "fixed"
    assert bonus2.valid?
    bonus2.save

    # assign to employee
    employee.bonuses << bonus
    employee.bonuses << bonus2


    # give work hours
    hours = {'2017-08-01' => 8,
             '2017-08-02' => 6,
             '2017-08-03' => 3.5,
             '2017-08-04' => 2,
             '2017-08-05' => 1,
             '2017-08-06' => 1.2,
             '2017-08-12' => 3.2}

    WorkHour.update employee, hours

    ### verify hours
    exp = {:normal => 171.5, :overtime => 5.4}
    assert_equal exp, WorkHour.total_hours(employee, Period.new(2017, 8))

    payslip = Payslip.process(employee, Period.new(2017,8))

    # should be (4):
    # overtime hours record
    # regular hours record
    # first bonus
    # second bonus
    assert_equal(4, payslip.earnings.size, "must have 4 entries after processing")

    count = 0

    payslip.earnings.each do |record|

        puts record.inspect
        # verify hours in earning records
        if (record.overtime == true && record.hours = 5.4)
            assert_equal(5.4, record.hours)
            count+=1
        end

        if (record.overtime == false && record.hours == 171.5)
            assert_equal(171.5, record.hours)
            count+=1
        end

        if (record.overtime == false && record.amount == 3000)
            assert_equal(3000.0, record.amount)
            count+=1
        end

        if (record.overtime == false && record.percentage == 12.0)
            assert_equal(12.0, record.percentage)
            count+=1
        end
    end

    assert_equal(4, count, "found all the items")

  end

  def test_payslip_with_period_information
    payslip = Payslip.new
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

    refute_nil(payslip.period_year, "year has been set by period")
    refute_nil(payslip.period_month, "month has been set by period")

    assert_equal(Date.today.year, payslip.period_year, "year is correct")
    assert_equal(Date.today.month, payslip.period_month, "month is correct")
  end

  def test_cannot_make_two_payslips_same_period
    employee = return_valid_employee()

    payslip = Payslip.new({
        payslip_date: "2017-07-31",
        period_year: Period.current.year,
        period_month: Period.current.month
    })
    refute_nil(payslip)

    employee.payslips << payslip
    create_earnings(payslip)

    assert(payslip.valid?)
    payslip.save

    assert(payslip.persisted?)
    refute_nil(payslip.id)

    # Attempt to reprocess payslip
    processed_payslip = Payslip.process(employee, Period.current)
    assert(processed_payslip)
    assert(processed_payslip.valid?, "reprocessed payslip should be valid")

    # verify it is the same payslip (earnings would have changed)
    assert_equal(payslip.id, processed_payslip.id, "ids have not changed")
    assert_equal(payslip.payslip_date, processed_payslip.payslip_date,
                  "pay date has not changed")
    refute_equal(payslip.last_processed, processed_payslip.last_processed,
                  "last Processed has changed")

  end

end
