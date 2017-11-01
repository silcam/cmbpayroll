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
    generate_work_hours employee, Period.new(2017, 8)

    hours = {'2017-08-01' => 8,
             '2017-08-02' => 6,
             '2017-08-03' => 3.5,
             '2017-08-04' => 2,
             '2017-08-05' => 1,
             '2017-08-06' => 1.2}

    WorkHour.update employee, hours, {}

    ### verify hours
    exp = {:normal => 172.5, :holiday => 1.2}
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
    generate_work_hours employee, Period.new(2017, 8)
    employee.wage = 100
    assert employee.valid?

    # create bonuses
    bonus = Bonus.new
    bonus.name = "First Bonus"
    bonus.quantity = 12.0
    bonus.percentage!
    assert bonus.valid?
    bonus.save

    bonus2 = Bonus.new
    bonus2.name = "Second Bonus"
    bonus2.quantity = 3000
    bonus2.fixed!
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

    WorkHour.update employee, hours, {}

    ### verify hours
    exp = {:normal => 175.7, :holiday => 1.2}
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
        # verify hours in earning records
        if (record.overtime == true && record.hours = 1.2)
            assert_equal(1.2, record.hours)
            count+=1
        end

        if (record.overtime == false && record.hours == 175.7)
            assert_equal(175.7, record.hours)
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
    generate_work_hours employee, Period.new(2017, 8)

    payslip = Payslip.new({
        payslip_date: "2017-09-01",
        period_year: 2017,
        period_month: 8
    })
    refute_nil(payslip)

    employee.payslips << payslip
    create_earnings(payslip)

    assert(payslip.valid?)
    payslip.save

    assert(payslip.persisted?)
    refute_nil(payslip.id)

    # Attempt to reprocess payslip
    processed_payslip = Payslip.process(employee, Period.new(2017, 8))
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
         assert(ded.valid?, "should be valid")
         count += 1
      end

      if (ded.note == "CHARGE2")
         assert_equal(2000, ded.amount)
         assert_equal(Date.today, ded.date)
         assert(ded.valid?, "should be valid")
         count += 1
      end
    end

    assert_equal(2, count, "found both deductions")
    assert_equal(charge1.amount + charge2.amount, payslip.total_deductions())

  end


  test "process_all_payslips_for_period" do

    employee_count = Employee.all.size
    period = Period.new(2017, 8)

    # have an employee
    employee1 = return_valid_employee()
    employee1.first_name = "EMPNumber"
    employee1.last_name = "One"
    employee1.category_one!
    employee1.echelon_d!
    employee1.save
    generate_work_hours employee1, period
    assert(employee1.valid?, "employee 1 should be valid")
    assert_equal(0, employee1.payslips.size, "should have no payslips initially")

    employee2 = return_valid_employee()
    employee2.first_name = "EMPNumber"
    employee2.last_name = "Two"
    employee2.category_one!
    employee2.echelon_f!
    employee2.save
    generate_work_hours employee2, period
    assert(employee2.valid?, "employee 2 should be valid")
    assert_equal(0, employee2.payslips.size, "should have no payslips initially")

    # made two employees
    assert_equal(2, Employee.all.size - employee_count)

    # each employee doesn't have a payslip
    assert_equal(0, employee1.payslips.size)
    assert_equal(0, employee2.payslips.size)

    # process all payslips
    payslips = Payslip.process_all(period)

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
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # advance payslip is created
    payslip.valid?
    assert payslip.id

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

  test "payslips deduct amical and union dues" do
    # have an employee
    employee = return_valid_employee()

    # give amical and union
    employee.amical = 3000
    employee.uniondues = true

    union_dues = employee.union_dues_amount

    # process a payslip
    payslip = Payslip.process(employee, Period.current)

    # verify there are deductions for Amical and Union.
    assert_equal(2, payslip.deductions.size, "payslip should have 2 deductions")

    count = 0
    payslip.deductions.each do |ded|
      if (/amical/i =~ ded.note)
         assert_equal(3000, ded.amount)
         assert_equal(Date.today.beginning_of_month(), ded.date)
         count += 1
      end

      if (/union/i =~ ded.note)
         assert_equal(union_dues, ded.amount)
         assert_equal(Date.today.beginning_of_month(), ded.date)
         count += 1
      end
    end

    assert_equal(2, count, "found both deductions")
  end

  test "payslips includes loan payments as deductions" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)

    # create loan
    loan = Loan.new
    loan.employee = employee
    loan.origination = "2017-08-01"
    loan.amount = 50000
    loan.comment = "aug loan"
    loan.term = "six_month_term"

    assert(loan.valid?, "loan should be valid")

    pay = LoanPayment.new
    pay.amount = "2500"
    pay.date = "2017-08-02"
    pay.save

    loan.loan_payments << pay
    loan.save

    assert(pay.valid?, "payment should be valid")
    assert_equal(Date.new(2017,8,2), pay.date)

    payslip = Payslip.process(employee, Period.new(2017,8))

    # check deductions
    deductions = payslip.deductions.where(note: LoanPayment::LOAN_PAYMENT_NOTE)
    assert_equal(1, deductions.size)
    assert_equal(pay.amount, deductions.first.amount)
    assert_equal(pay.date, deductions.first.date)

    # check loan balance
    assert_equal(loan.amount - pay.amount, payslip.loan_balance)
  end

  test "Payslip handles no loans" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)

    payslip = Payslip.process(employee, Period.new(2017,8))

    # check deductions
    deductions = payslip.deductions.where(note: LoanPayment::LOAN_PAYMENT_NOTE)
    assert_equal(0, deductions.size)

    # check loan balance
    assert_equal(0, payslip.loan_balance)
  end

  test "payslip can be re-run with loans" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)

    # create loan
    loan = Loan.new
    loan.employee = employee
    loan.origination = "2017-08-01"
    loan.amount = 8000
    loan.comment = "aug loan"
    loan.term = "six_month_term"

    assert(loan.valid?, "loan should be valid")

    pay = LoanPayment.new
    pay.amount = "2000"
    pay.date = "2017-08-02"
    pay.save

    loan.loan_payments << pay
    loan.save

    assert(pay.valid?, "payment should be valid")
    assert_equal(Date.new(2017,8,2), pay.date)

    payslip = Payslip.process(employee, Period.new(2017,8))

    # check deductions
    deductions = payslip.deductions.where(note: LoanPayment::LOAN_PAYMENT_NOTE)
    assert_equal(1, deductions.size)
    assert_equal(pay.amount, deductions.first.amount)
    assert_equal(pay.date, deductions.first.date)

    # check loan balance
    assert_equal(loan.amount - pay.amount, payslip.loan_balance)

    # REPROCESS
    payslip = Payslip.process(employee, Period.new(2017,8))

    deductions = payslip.deductions.where(note: LoanPayment::LOAN_PAYMENT_NOTE)
    assert_equal(1, deductions.size)
    assert_equal(loan.amount - pay.amount, payslip.loan_balance)
  end

  test "multiple loans make mupltiple deductions" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)

    # create loan
    loan = Loan.new
    loan.employee = employee
    loan.origination = "2017-08-01"
    loan.amount = 8000
    loan.comment = "aug loan"
    loan.term = "six_month_term"

    loan_other = Loan.new
    loan_other.employee = employee
    loan_other.origination = "2017-08-15"
    loan_other.amount = 10000
    loan_other.comment = "aug loan 2"
    loan_other.term = "six_month_term"

    assert(loan.valid?, "loan should be valid")
    assert(loan_other.valid?, "loan should be valid")

    pay = LoanPayment.new
    pay.amount = "2000"
    pay.date = "2017-08-02"
    pay.save

    loan.loan_payments << pay
    loan.save

    pay_other = LoanPayment.new
    pay_other.amount = "2000"
    pay_other.date = "2017-08-02"
    pay_other.save

    loan_other.loan_payments << pay_other
    loan_other.save

    payslip = Payslip.process(employee, Period.new(2017,8))

    # check deductions
    deductions = payslip.deductions.where(note: LoanPayment::LOAN_PAYMENT_NOTE)
    assert_equal(2, deductions.size)

    # check loan balance
    assert_equal((loan.amount + loan_other.amount) - (pay.amount + pay_other.amount), payslip.loan_balance)
  end

  test "payslip with paid loan" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)

    # create loan
    loan = Loan.new
    loan.employee = employee
    loan.origination = "2017-08-01"
    loan.amount = 8000
    loan.comment = "aug loan"
    loan.term = "six_month_term"

    pay = LoanPayment.new
    pay.amount = "8000"
    pay.date = "2017-08-02"
    pay.save

    loan.loan_payments << pay
    loan.save

    payslip = Payslip.process(employee, Period.new(2017,8))

    # check deductions
    deductions = payslip.deductions.where(note: LoanPayment::LOAN_PAYMENT_NOTE)
    assert_equal(1, deductions.size)

    # check loan balance
    assert_equal(0, payslip.loan_balance)
  end

  test "BasePay" do
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.wage_period = "monthly"
    employee.hours_day = 8
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "f"
    employee.wage_scale = "a"

    period = Period.new(2017,12)

    # work some of the month
    hours = {
      "2017-12-01" => 8
    }
    WorkHour.update(employee, hours, {})
    payslip = Payslip.process(employee, period)

    assert_equal(108580, employee.wage)
    assert_equal(5008, employee.daily_rate)
    # including 12/25
    assert_equal(2, payslip.days_worked)
    assert_equal(10016, payslip.base_pay)

    # work 6 hours on 12/1
    # switch to hourly
    hours = {
      "2017-12-01" => 6
    }
    employee.wage_period = "hourly"
    WorkHour.update(employee, hours, {})

    assert_equal(626, employee.hourly_rate)
    assert_equal(14, payslip.hours_worked)
    assert_equal(8764, payslip.base_pay)

    # work the whole month (work hour)
    employee.wage_period = "monthly"
    hours = {
      "2017-12-01" => 8
    }
    WorkHour.update(employee, hours, {})
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert(payslip.worked_full_month?, "now has worked whole month")
    assert_equal(employee.wage, payslip.base_pay)
  end

  test "BonusBase Full Month" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "monthly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"

    period = LastPostedPeriod.current

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert_equal(23, payslip.days_worked())
    assert_equal(184, payslip.hours_worked())
    assert(payslip.worked_full_month?)
    assert(employee.paid_monthly?)

    # compute bonusbase
    assert_equal(79475, employee.wage)
    assert_equal(employee.wage, payslip.bonusbase)
  end

  test "BonusBase Partial Month" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "monthly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"

    jan18 = Period.new(2018,1)

    # work a partial month (6 days)
    hours = {
      '2018-01-01' => 8,
      '2018-01-02' => 8,
      '2018-01-03' => 8,
      '2018-01-04' => 8,
      '2018-01-05' => 8,
      '2018-01-08' => 8
    }

    WorkHour.update(employee, hours, {})
    payslip = Payslip.process(employee, jan18)

    assert_equal(6, payslip.days_worked(), "worked 6 days")
    assert_equal(48, payslip.hours_worked(), "worked 48 hours")
    assert(employee.paid_monthly?, "employee is paid monthly")
    refute(payslip.worked_full_month?, "worked partial month in jan18")

    # compute bonusbase
    assert_equal(79475, employee.wage, "wage is expected")
    assert_equal(3672, employee.daily_rate, "daily rate is computed")
    assert_equal(22032, payslip.bonusbase, "proper bonus base for 6 days")
  end

  test "BonusBase Hourly Month" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "hourly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"

    period = LastPostedPeriod.current

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert_equal(23, payslip.days_worked())
    assert_equal(184, payslip.hours_worked())
    assert(payslip.worked_full_month?)
    refute(employee.paid_monthly?)

    # compute bonusbase
    assert_equal(79475, employee.wage)
    assert_equal(84456, payslip.bonusbase, "I'm not sure this is really correct")
  end

  test "Overtime Rates" do
    employee = return_valid_employee()

    employee.hours_day = 8
    employee.days_week = "five"
    employee.category = 6
    employee.echelon = "g"
    employee.wage = "117215"
    assert_equal(117215, employee.wage)

    assert(811.19 < employee.otrate && employee.otrate < 811.20)
    assert(878.8 < employee.ot2rate && employee.ot2rate < 878.81)
    assert_equal(946.4, employee.ot3rate)
  end

  test "BonusBase Hourly Partial Month" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "hourly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"

    jan18 = Period.new(2018,1)

    # work a partial month (6 days)
    hours = {
      '2018-01-01' => 8,
      '2018-01-02' => 8,
      '2018-01-03' => 8,
      '2018-01-04' => 8,
      '2018-01-05' => 8,
      '2018-01-08' => 8
    }

    WorkHour.update(employee, hours, {})
    payslip = Payslip.process(employee, jan18)

    assert_equal(48, payslip.hours_worked(), "worked 48 hours")
    refute(employee.paid_monthly?, "employee is paid hourly")
    refute(payslip.worked_full_month?, "worked partial month in jan18")

    # compute bonusbase
    assert_equal(79475, employee.wage, "wage is expected")
    assert_equal(459, employee.hourly_rate, "hourly rate is computed")
    assert_equal(22032, payslip.bonusbase, "proper bonus base for 6 days")
  end

  test "BonusBase Full Month with OT1" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "monthly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "b"
    employee.wage_scale = "a"

    jan18 = Period.new(2018,1)

    generate_work_hours employee, jan18
    # full month, except 10 hours on 1/1
    hours = {
      '2018-01-01' => 10,
    }

    WorkHour.update(employee, hours, {})
    payslip = Payslip.process(employee, jan18)

    assert(employee.paid_monthly?, "employee is paid monthly")
    assert(payslip.worked_full_month?, "worked full month in jan18")

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(492, employee.hourly_rate, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate, "daily rate is computed")

    # 85300 + OT hours (2 * (hourlyrate * 1.2)) or
    assert_equal(86481, payslip.bonusbase, "proper bonus base for 2 OT1")
  end

  test "BonusBase with OT2" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "monthly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "b"
    employee.wage_scale = "a"

    jan18 = Period.new(2018,1)

    generate_work_hours employee, jan18
    # full month, except 10 hours on 1/1
    hours = {
      '2018-01-01' => 17,
    }

    WorkHour.update(employee, hours, {})
    payslip = Payslip.process(employee, jan18)

    exp = {:normal => 184, :overtime => 8, :overtime2 => 1}
    hrs = WorkHour.total_hours(employee, jan18)
    assert_equal(exp, hrs)

    assert(employee.paid_monthly?, "employee is paid monthly")
    assert(payslip.worked_full_month?, "worked full month in jan18")

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(492, employee.hourly_rate, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate, "daily rate is computed")

    expected = (85300 + (8 * (employee.hourly_rate * 1.2)) +
        (1 * (employee.hourly_rate * 1.3))).ceil
    assert_equal(expected, payslip.bonusbase,
        "proper bonus base for 8 OT/1 OT2")
  end

  test "BonusBase Hourly Partial Month with OT3" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "monthly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "b"
    employee.wage_scale = "a"

    jan18 = Period.new(2018,1)

    generate_work_hours employee, jan18
    # full month, except 10 hours on 1/1
    hours = {
      '2018-01-01' => 17,
      '2018-01-02' => 18,
    }

    WorkHour.update(employee, hours, {})
    payslip = Payslip.process(employee, jan18)

    exp = {:normal => 184, :overtime => 8, :overtime2 => 8, :overtime3 => 3}
    hrs = WorkHour.total_hours(employee, jan18)
    assert_equal(exp, hrs)

    assert(employee.paid_monthly?, "employee is paid monthly")
    assert(payslip.worked_full_month?, "worked full month in jan18")

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(492, employee.hourly_rate, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate, "daily rate is computed")

    expected = (85300 + (8 * (employee.hourly_rate * 1.2)) +
        (8 * (employee.hourly_rate * 1.3)) +
          (3 * (employee.hourly_rate * 1.4))).ceil
    assert_equal(expected, payslip.bonusbase,
        "proper bonus base for 8 OT/8 OT2/3 OT3")
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
