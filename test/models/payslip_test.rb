require "test_helper"

class PayslipTest < ActiveSupport::TestCase

  test "from_period_methods" do
      payslip = Payslip.current_period

      assert_equal(Period.current.year, payslip.period_year)
      assert_equal(Period.current.month, payslip.period_month)

      january = Period.new(2017, 1)
      payslip = Payslip.from_period(january)

      assert_equal(january.year, payslip.period_year)
      assert_equal(january.month, payslip.period_month)
  end

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

    refute(payslip.valid?, "payslip should not be valid without earnings")
    refute(payslip.errors[:earnings].empty?, "yep, errors")

    create_earnings(payslip)

    assert(payslip.earnings.size == 1, "should have one earnings record")

    assert(payslip.valid?, "payship with earnings should be valid")
    assert(payslip.errors[:earnings].empty?, "no errors should be found")
  end

  test "last processed date should be generated" do
    employee = return_valid_employee()

    payslip = Payslip.process(employee)

    refute_nil(payslip.last_processed)
  end

  test "is valid with earnings records of 0" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()
    payslip.payslip_date = "2017-07-31"
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

    refute(payslip.valid?, "payslip should not be valid without earnings")
    refute(payslip.errors[:earnings].empty?, "yep, errors")

    # create an earning record with zeros (should be valid)
    earning = Earning.new
    earning.hours = 0
    earning.rate = 0
    payslip.earnings << earning

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

        Rails.logger.debug(record.inspect)
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

  test "test_payslip_with_period_information" do
    payslip = Payslip.new
    payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month

    refute_nil(payslip.period_year, "year has been set by period")
    refute_nil(payslip.period_month, "month has been set by period")

    assert_equal(Date.today.year, payslip.period_year, "year is correct")
    assert_equal(Date.today.month, payslip.period_month, "month is correct")
  end

  test "test_cannot_make_two_payslips_same_period" do
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

  test "test_payslip_can_return_period" do

    payslip = Payslip.new
    assert_nil(payslip.period)

    payslip = Payslip.new({
        payslip_date: "2017-07-31",
        period_year: Period.current.year,
        period_month: Period.current.month
    })

    period = payslip.period()

    assert_equal(0, Period.current <=> period, "should be equal")

  end


  test "charges_become_deductions" do

    # have an employee
    employee = return_valid_employee()

    # make charges
    charge1 = Charge.new
    charge1.note = "CHARGE1"
    charge1.amount = 1000
    charge1.date = Date.today
    employee.charges << charge1

    Rails.logger.debug(charge1.errors.inspect)
    assert(charge1.valid?, "charge 1 is valid")

    charge2 = Charge.new
    charge2.note = "CHARGE2"
    charge2.amount = 2000
    charge2.date = Date.today
    employee.charges << charge2

    Rails.logger.debug(charge2.errors.inspect)
    assert(charge2.valid?, "charge 2 is valid")

    assert_equal(2, employee.charges.size, "should have 2 charges")
    assert(employee.valid?, "should be valid")

    # process a payslip
    payslip = Payslip.process(employee, Period.current)

    # verify there are deductions for the charges.
    assert_equal(2, payslip.deductions.size, "payslip should have 2 deductions")

    count = 0
    payslip.deductions.each do |ded|
      if (ded.note == "CHARGE1")
         assert_equal(1000, ded.amount)
         assert_equal(Date.today, ded.date)
         count += 1
      end

      if (ded.note == "CHARGE2")
         assert_equal(2000, ded.amount)
         assert_equal(Date.today, ded.date)
         count += 1
      end
    end

    assert_equal(2, count, "found both deductions")
    assert_equal(charge1.amount + charge2.amount, payslip.total_deductions())

  end


  test "process_all_payslips_for_period" do

    employee_count = Employee.all.size

    # have an employee
    employee1 = return_valid_employee()
    employee1.first_name = "EMPNumber"
    employee1.last_name = "One"
    employee1.save
    assert(employee1.valid?, "employee 1 should be valid")
    assert_equal(0, employee1.payslips.size, "should have no payslips initially")

    employee2 = return_valid_employee()
    employee2.first_name = "EMPNumber"
    employee2.last_name = "Two"
    employee2.save
    assert(employee2.valid?, "employee 2 should be valid")
    assert_equal(0, employee2.payslips.size, "should have no payslips initially")

    # made two employees
    assert_equal(2, Employee.all.size - employee_count)

    # each employee doesn't have a payslip
    assert_equal(0, employee1.payslips.size)
    assert_equal(0, employee2.payslips.size)

    # process all payslips
    payslips = Payslip.process_all(Period.current)

    # processed one for each employee
    assert_equal(employee_count + 2, payslips.size)

    # let's checkout each object
    val = true
    count = 0
    payslips.each do |record|
      next unless (record.employee.full_name == employee1.full_name ||
                   record.employee.full_name == employee2.full_name)
      count += 1
      unless (record.valid?)
        val = false
      end
    end
    assert_equal(2, count, "found one payslip for each employee")
    assert(val, "one of the payslips isn't valid")

    payslips.each do |ps|
      Rails.logger.debug("   -> PS(#{ps.id}) for: #{ps.employee.full_name}")
    end

    Employee.all.each do |record|
      next unless (record.full_name == employee1.full_name ||
                   record.full_name == employee2.full_name)
      Rails.logger.debug("oooooX for #{record.full_name}:")
      Rails.logger.debug("     V: #{record.payslips.size}")
      unless (record.valid?)
        val = false
      end
    end

    employee1.reload
    employee2.reload

    # make sure each employee received a payslip
    assert_equal(1, employee1.payslips.size, "employee 1 should now have 1 payslip")
    assert_equal(1, employee2.payslips.size, "employee 2 should now have 1 payslip")

  end

  test "can_create_payslip_advance" do

    period = Period.new(2017,8)

    # process with flag to handle advance
    employee = return_valid_employee()

    payslip = Payslip.process(employee, period)

    # advance payslip is created
    payslip.valid?
    assert(employee.payslips.find(payslip.id))

    # find charges (check that no advance is created for this month
    count = employee.count_advance_charge(period)
    assert_equal(0, count, "should not find a Salary Advance charge")

    count = count_advance_deductions(payslip, period)
    assert_equal(0, count, "should find a Salary Advance deduction")

    # confirmation happens
    payslip = Payslip.process_with_advance(employee, period)

    # advance payslip is created
    payslip.valid?
    assert(employee.payslips.find(payslip.id))

    # appropriate charges are created for the user to indicate payment has been made
    count = employee.count_advance_charge(period)
    assert_equal(1, count, "should find a Salary Advance charge")

    count = count_advance_deductions(payslip, period)
    assert_equal(1, count, "should find a Salary Advance deduction")

    # it is not in a finalized? state
    # TODO, this doesn't exist

    # a payslip can be re-created and the advance is still there.

    # let's re-run the payslip (unconfirmed)
    payslip = Payslip.process(employee, period)

    count = employee.count_advance_charge(period)
    assert_equal(1, count, "should find a Salary Advance charge")

    count = count_advance_deductions(payslip, period)
    assert_equal(1, count, "should find a Salary Advance deduction")

    # let's re-run the payslip (confirmed)
    # it should not recreate another charge for the same peirod
    payslip = Payslip.process_with_advance(employee, period)

    count = employee.count_advance_charge(period)
    assert_equal(1, count, "should find a Salary Advance charge")

    count = count_advance_deductions(payslip, period)
    assert_equal(1, count, "should find a Salary Advance deduction")

  end


  private

  def count_advance_deductions(payslip, period)
    count = 0

    # find charges (check that no advance is created for this month
    payslip.deductions.each do |ded|
      next if (ded.date < period.start)
      next if (ded.date > period.finish)

      if (ded.note == Charge::ADVANCE)
        count += 1
      end
    end

    return count
  end


end
