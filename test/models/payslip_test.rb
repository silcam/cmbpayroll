require "test_helper"
require "logger"

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

    payslip.net_pay = 1
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
    payslip.net_pay = 1

    create_earnings(payslip)

    value(payslip).wont_be :valid?

    payslip.employee = employee
    assert(payslip.valid?)
  end

  # test "is not valid without payslip date" do
  #   employee = return_valid_employee()
  #
  #   payslip = employee.payslips.create()
  #
  #   #payslip.payslip_date = "2017-07-31"
  #   payslip.period_year = Period.current.year
  #   payslip.period_month = Period.current.month
  #
  #   create_earnings(payslip)
  #
  #   refute(payslip.valid?)
  #   payslip.payslip_date = "2017-07-31"
  #   assert(payslip.valid?)
  # end

  test "is not valid without period start" do
    employee = return_valid_employee()

    payslip = employee.payslips.create()

    payslip.payslip_date = "2017-07-31"
    #payslip.period_year = Period.current.year
    payslip.period_month = Period.current.month
    payslip.net_pay = 1

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
    payslip.net_pay = 1

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
    payslip.net_pay = 1

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
    payslip.net_pay = 1

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

    hours = {'2017-08-01' => {hours: 8},
             '2017-08-02' => {hours: 6},
             '2017-08-03' => {hours: 3.5},
             '2017-08-04' => {hours: 2},
             '2017-08-05' => {hours: 1},
             '2017-08-06' => {hours: 1.2}}

    WorkHour.update employee, hours

    ### verify hours
    exp = {normal: 171.5, overtime: 1, holiday: 1.2}
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
    assert employee.valid?

    # create bonuses
    bonus = Bonus.new
    bonus.name = "First Bonus"
    bonus.quantity = 0.12
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

    assert_equal(2, employee.bonuses.size)

    # give work hours
    hours = {'2017-08-01' => {hours: 8},
             '2017-08-02' => {hours: 6},
             '2017-08-03' => {hours: 3.5},
             '2017-08-04' => {hours: 2},
             '2017-08-05' => {hours: 1},
             '2017-08-06' => {hours: 1.2},
             '2017-08-12' => {hours: 3.2}}

    WorkHour.update employee, hours

    ### verify hours
    exp = {normal: 171.5, overtime: 4.2,  holiday: 1.2}
    assert_equal exp, WorkHour.total_hours(employee, Period.new(2017, 8))

    payslip = Payslip.process(employee, Period.new(2017,8))

    count = 0
    # should have (6):
    #   regular earnings record
    #   overtime hours record
    #   overtime 2 hours record
    #   overtime 3 hours record
    #   first bonus
    #   second bonus

    # Find specific earnings entries
    assert_equal(1,
        payslip.earnings.where(description: "First Bonus").size())
    assert_equal(1,
        payslip.earnings.where(description: "Second Bonus").size())
    assert_equal(1,
        payslip.earnings.where(hours: 1.2).size())
    assert_equal(1,
        payslip.earnings.where(hours: 1.2).size())
    payslip.earnings.where(description: "First Bonus")
    payslip.earnings.where(description: "First Bonus")

    assert_equal(6, payslip.earnings.size, "must have 6 entries after processing")
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
    payslip.net_pay = 1

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
    employee.uniondues = false;
    employee.amical = 0;

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
    employee1.employment_status = "full_time"
    employee1.save
    generate_work_hours employee1, period
    assert(employee1.valid?, "employee 1 should be valid")
    assert_equal(0, employee1.payslips.size, "should have no payslips initially")

    employee2 = return_valid_employee()
    employee2.first_name = "EMPNumber"
    employee2.last_name = "Two"
    employee2.category_one!
    employee2.echelon_f!
    employee2.employment_status = "full_time"
    employee2.save
    generate_work_hours employee2, period
    assert(employee2.valid?, "employee 2 should be valid")
    assert_equal(0, employee2.payslips.size, "should have no payslips initially")

    employee3 = return_valid_employee()
    employee3.first_name = "EMPNumber"
    employee3.last_name = "Three"
    employee3.category_one!
    employee3.echelon_f!
    employee3.employment_status = "leave"
    employee3.save
    generate_work_hours employee3, period
    assert(employee3.valid?, "employee 3 should be valid")
    assert_equal(0, employee3.payslips.size, "should have no payslips initially")

    # made three employees
    assert_equal(3, Employee.all.size - employee_count)

    # each employee doesn't have a payslip
    assert_equal(0, employee1.payslips.size)
    assert_equal(0, employee2.payslips.size)
    assert_equal(0, employee3.payslips.size)

    # process all payslips
    payslips = Payslip.process_all(period)

    # processed one for 2 employees (except 1 on leave)
    assert_equal(employee_count + 2, payslips.size,
        "should have processed correct number of payslips")

    # let's checkout each object
    val = true
    count = 0
    payslips.each do |record|
      next unless (record.employee.full_name == employee1.full_name ||
                   record.employee.full_name == employee2.full_name ||
                   record.employee.full_name == employee3.full_name)
      count += 1
      unless (record.valid?)
        val = false
      end
    end
    assert_equal(2, count, "found one payslip for each employee (not emp3)")
    assert(val, "one of the payslips isn't valid")

    payslips.each do |ps|
      Rails.logger.debug("   -> PS(#{ps.id}) for: #{ps.employee.full_name}")
    end

    Employee.all.each do |record|
      next unless (record.full_name == employee1.full_name ||
                   record.full_name == employee2.full_name ||
                   record.full_name == employee3.full_name)
      Rails.logger.debug("oooooX for #{record.full_name}:")
      Rails.logger.debug("     V: #{record.payslips.size}")
      unless (record.valid?)
        val = false
      end
    end

    employee1.reload
    employee2.reload
    employee3.reload

    # make sure each employee received a payslip
    assert_equal(1, employee1.payslips.size, "employee 1 should now have 1 payslip")
    assert_equal(1, employee2.payslips.size, "employee 2 should now have 1 payslip")
    assert_equal(0, employee3.payslips.size, "employee 3 should not have 1 payslip")
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

  test "Payslip doesn't deduct loan payments made in cash" do
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
    refute(pay.cash?, "payment should not be a cash payment")
    assert_equal(Date.new(2017,8,2), pay.date)

    cash_pay = LoanPayment.new
    cash_pay.amount = "7500"
    cash_pay.date = "2017-08-04"
    cash_pay.cash_payment = true
    cash_pay.save

    loan.loan_payments << cash_pay
    loan.save

    assert(cash_pay.valid?, "payment should be valid")
    assert(cash_pay.cash?, "this payment should be a cash payment")
    assert_equal(Date.new(2017,8,4), cash_pay.date)

    payslip = Payslip.process(employee, Period.new(2017,8))

    # check deductions
    deductions = payslip.deductions.where(note: LoanPayment::LOAN_PAYMENT_NOTE)
    assert_equal(1, deductions.size)
    assert_equal(pay.amount, deductions.first.amount)
    assert_equal(pay.date, deductions.first.date)

    # check loan balance (should be reduced by both payments)
    assert_equal(loan.amount - pay.amount - cash_pay.amount, payslip.loan_balance)
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

  test "payslips cannot be run non F,P,or T employees" do
    employee = return_valid_employee()
    employee.employment_status = "leave"

    jan = Period.new(2018,1)
    generate_work_hours employee, Period.new(2018, 1)

    nil_payslip = Payslip.process(employee, jan)
    assert_nil(nil_payslip, "should not process anything for a leave employee")
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

  test "Sick Time is still paid" do
    employee = return_valid_employee()
    period = Period.new(2018,1)

    generate_work_hours employee, period

    hours = {
      "2018-01-02" => {hours: 0.0, excused_hours: '8', excuse: 'Sick'}
    }

    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, period)

    assert_equal(23, employee.workdays_per_month(period))
    assert_equal(23, WorkHour.days_worked(employee, period))
    assert(payslip.worked_full_month?, "Despite one sick day, worked whole month")
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

    Holiday.new(name: "Christmas", date: "2017-12-25")

    # work some of the month
    hours = {
      "2017-12-01" => {hours: 8}
    }
    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, period)

    assert_equal(108580, employee.wage)
    assert_equal(5008, employee.daily_rate)
    # including 12/25
    assert_equal(2, payslip.days_worked)
    assert_equal(10016, payslip.base_pay)

    # Work the whole month
    hours = {
      "2017-12-01" => {hours: 8},
      "2017-12-25" => {hours: 0}
    }
    WorkHour.update(employee, hours)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert(employee.paid_monthly?, "emp is monthly")
    assert(payslip.employee.paid_monthly?, "pemp is monthly")

    assert(payslip.worked_full_month?, "now has worked whole month")
    assert_equal(employee.wage, payslip.base_pay)

    assert_equal((payslip.basepay + payslip.overtime_earnings).ceil,
        payslip.earnings.where(is_bonus: false).sum(:amount).ceil)
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
    assert_equal(employee.wage, payslip.compute_bonusbase)
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
      '2018-01-01' => {hours: 8},
      '2018-01-02' => {hours: 8},
      '2018-01-03' => {hours: 8},
      '2018-01-04' => {hours: 8},
      '2018-01-05' => {hours: 8},
      '2018-01-08' => {hours: 8}
    }

    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, jan18)

    assert_equal(6, payslip.days)
    assert_nil(payslip.hours)

    assert_equal(6, payslip.days_worked(), "worked 6 days")
    assert_equal(48, payslip.hours_worked(), "worked 48 hours")
    assert(employee.paid_monthly?, "employee is paid monthly")
    refute(payslip.worked_full_month?, "worked partial month in jan18")

    # compute bonusbase
    assert_equal(79475, employee.wage, "wage is expected")
    assert_equal(3672, employee.daily_rate, "daily rate is computed")
    assert_equal(22032, payslip.compute_bonusbase, "proper bonus base for 6 days")
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

    assert_equal(184, payslip.hours)
    assert_nil(payslip.days)

    assert(payslip.worked_full_month?)
    refute(employee.paid_monthly?)

    # compute bonusbase
    assert_equal(79475, employee.wage)
    assert_equal(84456, payslip.compute_bonusbase, "I'm not sure this is really correct")
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
      '2018-01-01' => {hours: 8},
      '2018-01-02' => {hours: 8},
      '2018-01-03' => {hours: 8},
      '2018-01-04' => {hours: 8},
      '2018-01-05' => {hours: 8},
      '2018-01-08' => {hours: 8}
    }

    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, jan18)

    assert_equal(48, payslip.hours)
    assert_equal(48, payslip.hours_worked(), "worked 48 hours")

    refute(employee.paid_monthly?, "employee is paid hourly")
    refute(payslip.worked_full_month?, "worked partial month in jan18")

    # compute bonusbase
    assert_equal(79475, employee.wage, "wage is expected")
    assert_equal(459, employee.hourly_rate, "hourly rate is computed")
    assert_equal(22032, payslip.compute_bonusbase, "proper bonus base for 6 days")
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
      '2018-01-01' => {hours: 10},
    }

    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, jan18)

    assert(employee.paid_monthly?, "employee is paid monthly")
    assert(payslip.worked_full_month?, "worked full month in jan18")

    assert_equal(2, payslip.overtime_hours)
    assert_equal(0, payslip.overtime2_hours)
    assert_equal(0, payslip.overtime3_hours)
    assert_equal(590, payslip.overtime_rate)
    assert_equal(639, payslip.overtime2_rate)
    assert_equal(688, payslip.overtime3_rate)

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(492, employee.hourly_rate, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate, "daily rate is computed")

    # 85300 + OT hours (2 * (hourlyrate * 1.2)) or
    assert_equal(86481, payslip.compute_bonusbase, "proper bonus base for 2 OT1")
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
      '2018-01-01' => {hours: 17},
    }

    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, jan18)

    hrs = WorkHour.total_hours(employee, jan18)
    exp = {:normal => 184, :overtime => 9}
    assert_equal(exp, hrs)
    ot_hrs = Payslip.overtime_tranches hrs
    exp = {ot1: 8, ot2: 1, ot3: 0}
    assert_equal exp, ot_hrs

    assert(employee.paid_monthly?, "employee is paid monthly")
    assert(payslip.worked_full_month?, "worked full month in jan18")

    assert_equal(8, payslip.overtime_hours)
    assert_equal(1, payslip.overtime2_hours)
    assert_equal(0, payslip.overtime3_hours)

    assert_equal(590, payslip.overtime_rate)
    assert_equal(639, payslip.overtime2_rate)
    assert_equal(688, payslip.overtime3_rate)

    assert_nil(payslip.days)
    assert_nil(payslip.hours)

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(492, employee.hourly_rate, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate, "daily rate is computed")

    expected = (85300 + (8 * (employee.hourly_rate * 1.2)) +
        (1 * (employee.hourly_rate * 1.3))).ceil
    assert_equal(expected, payslip.compute_bonusbase,
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
      '2018-01-01' => {hours: 17},
      '2018-01-02' => {hours: 18}
    }

    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, jan18)

    hrs = WorkHour.total_hours(employee, jan18)
    exp = {:normal => 184, :overtime => 19}
    assert_equal(exp, hrs)
    ot_hrs = Payslip.overtime_tranches hrs
    exp = {ot1: 8, ot2: 8, ot3: 3}
    assert_equal exp, ot_hrs

    assert(employee.paid_monthly?, "employee is paid monthly")
    assert(payslip.worked_full_month?, "worked full month in jan18")

    assert_nil(payslip.days)
    assert_nil(payslip.hours)

    assert_equal(8, payslip.overtime_hours)
    assert_equal(8, payslip.overtime2_hours)
    assert_equal(3, payslip.overtime3_hours)

    assert_equal(590, payslip.overtime_rate)
    assert_equal(639, payslip.overtime2_rate)
    assert_equal(688, payslip.overtime3_rate)

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(employee.wage, payslip.base_pay, "base_pay is good")
    assert_equal(492, employee.hourly_rate, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate, "daily rate is computed")

    expected = (85300 +
        (8 * (employee.hourly_rate * 1.2)) +
          (8 * (employee.hourly_rate * 1.3)) +
            (3 * (employee.hourly_rate * 1.4))).ceil

    assert_equal(expected, payslip.compute_bonusbase,
        "proper bonus base for 8 OT/8 OT2/3 OT3")

    nonbonus_earnings = payslip.earnings.where(is_bonus: false)
    assert_equal(4, nonbonus_earnings.size, "should have 4 earnings")
    assert_equal(expected,
        payslip.earnings.where(is_bonus: false).sum(:amount).ceil,
          "earnings should represent earnings")
  end

  test "CaisseBase" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "monthly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"
    employee.contract_start = Date.new(2010,1,1)

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert_equal(23, payslip.days_worked())
    assert_equal(184, payslip.hours_worked())
    assert(payslip.worked_full_month?)
    assert(employee.paid_monthly?)

    # compute caissebase
    wage = employee.wage
    base_wage = employee.find_base_wage
    assert_equal(8, employee.years_of_service(period))

    expected_caisse = ( 8 * 0.02 * base_wage + wage ).ceil

    # bonusbase (wage) + (seniority bonus (8 yrs * 0.02) * base_wage)
    assert_equal(expected_caisse, payslip.compute_caissebase)

    # You don't get seniority bonus in the first two years
    employee.contract_start = Date.new(2016,7,31)
    assert_equal(1, employee.years_of_service(period))

    # caissebase is now the same as compute_bonusbase
    assert_equal(payslip.compute_bonusbase, payslip.compute_caissebase)
  end

  test "CNPSWage and Taxable" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.hours_day = 8
    employee.wage_period = "monthly"
    employee.days_week = "five"
    employee.category = "four"
    employee.echelon = "a"
    employee.wage_scale = "a"
    employee.transportation = 20000
    employee.amical = 3000
    employee.uniondues = false
    employee.contract_start = Date.new(2010,1,1)

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # compute caissebase
    wage = employee.wage
    base_wage = employee.find_base_wage
    assert_equal(8, employee.years_of_service(period))

    # bonusbase (wage) + (seniority bonus (8 yrs * 0.02) * base_wage)
    exp_caisse = exp_cnps = ( ((8 * 0.02) * base_wage) + wage ).ceil
    assert_equal(exp_cnps, payslip.compute_cnpswage, "cnps same as caisse")

    # verify taxable (adds transportation)
    expected_taxable = exp_cnps + employee.transportation
    assert_equal(expected_taxable, payslip.process_taxable_wage, "taxable")

    assert_equal(0, payslip.earnings.where(is_bonus: true).count(), "no bonuses")

    # Add Prime de Caisse Bonus
    pdc_bonus = Bonus.create!(name: "Prime de Caisse 0.05", quantity: 0.05,
        bonus_type: "percentage")
    assert_equal(0, employee.bonuses.size)
    employee.bonuses << pdc_bonus
    assert_equal(1, employee.bonuses.size)
    payslip = Payslip.process(employee, period)

    # verify cnps
    exp_cnps_w_pdc = (exp_cnps + (exp_cnps * 0.05).floor).ceil # PDC Bonus
    assert_equal(exp_cnps_w_pdc, payslip.compute_cnpswage, "cnps with pdc")

    # Department CNPS
    assert_equal(( exp_cnps_w_pdc * SystemVariable.value(:dept_cnps) ).floor,
        payslip.department_cnps)

    # prime exceptionnel
    pe_bonus = Bonus.create!(name: "Prime Exceptionnelle", quantity: 0.30,
        bonus_type: "percentage")
    employee.bonuses << pe_bonus
    assert_equal(2, employee.bonuses.size)
    payslip = Payslip.process(employee, period)

    # verify cnps
    exp_pdc_pe = (exp_cnps + (exp_cnps * 0.05).floor +
          (exp_cnps * 0.30).floor).ceil # PDC + PE Bonus
    assert_equal(exp_pdc_pe, payslip.compute_cnpswage, "cnps with pdc + pe")

    # another bonus
    spot_bonus = Bonus.create!(name: "Spot Bonus", quantity: 10000,
        bonus_type: "fixed")
    employee.bonuses << spot_bonus
    assert_equal(3, employee.bonuses.size)
    payslip = Payslip.process(employee, period)

    # verify cnps
    exp_triple_bonus = (exp_cnps + (exp_cnps * 0.05).floor +
          (exp_cnps * 0.30).floor + 10000).ceil # PDC + PE Bonus
    assert_equal(exp_triple_bonus, payslip.compute_cnpswage, "cnps with pdc + pe + spot")
    new_exp_taxable = exp_triple_bonus + employee.transportation

    # Department Credit Foncier
    assert_equal( ( new_exp_taxable * SystemVariable.value(:dept_credit_foncier) ).floor,
        payslip.department_credit_foncier)

    # Dept Severance
    # years of service
    assert_equal(8, employee.years_of_service(period))
    # 40% for 8 years.
    assert_equal(( payslip.cnpswage * 0.4 ).floor, payslip.department_severance())

    # verify can find out which bonuses were attached to payslip.
    assert_equal(3, payslip.earnings.where(is_bonus: true).count(), "bonuses as earnings (3)")

    pdc_earning = Earning.find_by(payslip_id: payslip.id,
        description: pdc_bonus.name)
    assert(pdc_earning, "can find earning for pdc")
    assert(pdc_earning.valid?, "pdc is valid")

    pe_earning = Earning.find_by(payslip_id: payslip.id,
        description: pe_bonus.name)
    assert(pe_earning, "can find earning for pe")
    assert(pe_earning.valid?, "pe is valid")

    spot_earning = Earning.find_by(payslip_id: payslip.id,
        description: spot_bonus.name)
    assert(spot_earning, "can find earning for spot")
    assert(spot_earning.valid?, "spot is valid")

    # verify saved payslip attributes
    assert_equal(wage, payslip.bonusbase)
    assert_equal(exp_caisse, payslip.caissebase)
    assert_equal(exp_triple_bonus, payslip.cnpswage)
    assert_equal(new_exp_taxable, payslip.taxable)

    assert_equal(new_exp_taxable, payslip.gross_pay)

    assert_equal(employee.transportation, payslip.transportation)

    assert_equal(payslip.seniority_bonus, payslip.seniority_bonus_amount)
    assert_equal(employee.years_of_service(payslip.period), payslip.years_of_service)
    assert_equal(SystemVariable.value(:seniority_benefit), payslip.seniority_benefit)


    assert_equal(Employee.categories[employee.category], payslip.category)
    assert_equal(Employee.echelons[employee.echelon], payslip.echelon)
    assert_equal(Employee.wage_scales[employee.wage_scale], payslip.wagescale)

    assert_equal(employee.hourly_rate, payslip.hourly_rate)
    assert_equal(employee.daily_rate, payslip.daily_rate)

    assert_equal(416, payslip.communal)
    assert_equal(640, payslip.cac)
    assert_equal(0, payslip.cac2)
    assert_equal(5647, payslip.cnps)
    assert_equal(6397, payslip.proportional)
    assert_equal(1950, payslip.crtv)
    assert_equal(1542, payslip.ccf)
    assert_equal(154250, payslip.roundedpay)

    exp_total_tax = payslip.communal + payslip.cac +
        payslip.cac2 + payslip.cnps + payslip.proportional +
          payslip.crtv + payslip.ccf

    assert_equal(exp_total_tax, payslip.total_tax)
    assert_equal(new_exp_taxable - exp_total_tax - employee.amical, payslip.net_pay)
  end

  test "Dept CNPS Ceiling" do
    employee = return_valid_employee()

    employee.hours_day = 8
    employee.days_week = "five"
    employee.category = 6
    employee.echelon = "g"
    employee.wage = "900215"
    assert_equal(900215, employee.wage)

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # verify dept cnps ceiling
    expected_cnps = payslip.cnpswage()

    # If ceiling hit, CNPSWage * 0.0175 + 84 000
    assert_equal(
          ( expected_cnps *
              SystemVariable.value(:dept_cnps_w_ceil) + 84000 ).floor,
          payslip.department_cnps)
  end

  test "Employee Contributions (w and w/o ceiling) and Employee Funds (Dept Charges Report)" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.category = "nine"
    employee.echelon = "e"
    employee.wage_scale = "a"
    employee.contract_start = "2017-07-31"

    period = Period.new(2018,1)
    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert(employee.find_wage > SystemVariable.value(:emp_fund_salary_floor)) # default: 80 000
    assert_equal(SystemVariable.value(:emp_fund_amount), payslip.employee_fund) # default 13 000
    # TODO: What is this?
    assert_equal(0, payslip.employee_contribution)

    # Reduce wage so it is under salary floor and reprocess
    employee.category = "one"
    employee.echelon = "a"
    employee.wage_scale = "b"
    payslip = Payslip.process(employee, period)

    assert(payslip.taxable < SystemVariable.value(:emp_fund_salary_floor),
        "taxable is less than floor") # default: 80 000
    # No contribution under the contribution limit
    assert_equal(0, payslip.employee_fund)
    # TODO: What is this?
    assert_equal(0, payslip.employee_contribution)
  end

  test "Department Percentages from Work Loans (Dept Charges Report)" do
    # config employee
    employee = return_valid_employee()
    lss_dept = departments :LSS
    admin_dept = departments :Admin
    employee.department_id = lss_dept.id

    # create some work loans
    # 1 week - 40 hours.
    start = Date.new(2018,1,15)
    finish = Date.new(2018,1,19)
    (start..finish).each do |dt|
      wl = WorkLoan.new
      wl.date = dt
      wl.department = departments :Admin
      wl.hours = 8
      employee.work_loans << wl
    end

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # Verify that I have work loan percentages now.
    # January 18 has 23 working days (or 184 hours).
    # 40 / 184 is 21.739%
    count = 0
    payslip.work_loan_percentages.all.each do |wlp|
      if (wlp.department_id == admin_dept.id)
        assert_equal(21.74, (wlp.percentage * 100).round(2))
        count += 1
      else
        # the rest of the month
        assert_equal(78.26, (wlp.percentage * 100).round(2))
        count += 1
      end
    end
    assert_equal(2, count, "found two items")
  end

  test "No WorkLoans gives 1 entry" do
    # config employee
    employee = return_valid_employee()
    period = Period.new(2018,1)

    # no work loans

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # Verify that I have work loan percentages now.
    # January 18 has 23 working days (or 184 hours).
    # 40 / 184 is 21.739%
    assert_equal(1, payslip.work_loan_percentages.size, "should have exactly 1")
    assert_equal(1, payslip.work_loan_percentages.first.percentage, "should be 100%")
    assert_equal(employee.department_id, payslip.work_loan_percentages.first.department_id,
        "should be in employee's department")
  end

  test "Test Full Time Loaned" do
    # config employee
    employee = return_valid_employee()
    lss_dept = departments :LSS
    admin_dept = departments :Admin
    employee.department_id = lss_dept.id

    period = Period.new(2018,1)
    start_date = period.start
    finish_date = period.finish

    # Loan for every work day
    (start_date..finish_date).each do |dt|
      if (dt.wday > 0 && dt.wday < 6)
        wl = WorkLoan.new
        wl.date = "2018-01-15"
        wl.department = departments :Admin
        wl.hours = 8
        employee.work_loans << wl
      end
    end

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # Verify that I have work loan percentages now.
    # January 18 has 23 working days (or 184 hours).
    # 40 / 184 is 21.739%
    count = 0
    assert_equal(1, payslip.work_loan_percentages.size, "should only be one")
    assert_equal(1, payslip.work_loan_percentages.first.percentage, "should be for 100%")
    assert_equal(admin_dept.id, payslip.work_loan_percentages.first.department_id,
        "should be for admin dept")
  end

  test "Test Cannot be loaned more than 100% despite overtime" do
    # config employee
    employee = return_valid_employee()
    lss_dept = departments :LSS
    admin_dept = departments :Admin
    employee.department_id = lss_dept.id

    period = Period.new(2018,1)
    start_date = period.start
    finish_date = period.finish

    # Loan for every day (Even weekends)
    (start_date..finish_date).each do |dt|
      wl = WorkLoan.new
      wl.date = "2018-01-15"
      wl.department = departments :Admin
      wl.hours = 8
      employee.work_loans << wl
    end

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # Verify that I have work loan percentages now.
    # January 18 has 23 working days (or 184 hours).
    # 40 / 184 is 21.739%
    count = 0
    assert_equal(1, payslip.work_loan_percentages.size, "should only be one")
    assert_equal(1, payslip.work_loan_percentages.first.percentage, "should be for 100%")
    assert_equal(admin_dept.id, payslip.work_loan_percentages.first.department_id,
        "should be for admin dept")
  end

  test "Test Many Departments" do

    admin_dept = departments :Admin
    av_dept = departments :Aviation
    ctc_dept = departments :CTC
    rfis_dept = departments :RFIS
    cam_dept = departments :Cam
    lss_dept = departments :LSS

    to_create = {
      admin_dept => 16, #  8.695%
      av_dept => 40,    # 21.739%
      ctc_dept => 32,   # 17.391%
      rfis_dept => 8,   #  4.347%
      cam_dept => 64,   # 34.780%
    }
    # total: 152 hours | 86.956%

    # config employee
    employee = return_valid_employee()
    employee.department_id = lss_dept.id

    period = Period.new(2018,1)
    start_date = period.start
    finish_date = period.finish

    # Create Loans for every work day
    tmp_date = start_date
    to_create.each do |k,v|
      tmp_amount = v

      while (tmp_amount > 0)
        wl = WorkLoan.new
        wl.date = tmp_date
        wl.department = k
        wl.hours = 8
        employee.work_loans << wl

        tmp_date = tmp_date + 1
        tmp_amount -= 8
      end
    end

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # Verify that I have work loan percentages now.
    count = 0
    assert_equal(6, payslip.work_loan_percentages.size, "should be 6")

    payslip.work_loan_percentages.all.each do |wlp|
      if (wlp.department_id == admin_dept.id)
        assert_equal(8.70, (wlp.percentage * 100).round(2))
        count += 1
      elsif (wlp.department_id == av_dept.id)
        assert_equal(21.74, (wlp.percentage * 100).round(2))
        count += 1
      elsif (wlp.department_id == ctc_dept.id)
        assert_equal(17.39, (wlp.percentage * 100).round(2))
        count += 1
      elsif (wlp.department_id == rfis_dept.id)
        assert_equal(4.35, (wlp.percentage * 100).round(2))
        count += 1
      elsif (wlp.department_id == cam_dept.id)
        assert_equal(34.78, (wlp.percentage * 100).round(2))
        count += 1
      elsif (wlp.department_id == lss_dept.id)
        # the leftovers
        assert_equal(13.04, (wlp.percentage * 100).round(2))
        count += 1
      end
    end
    # 5 plus leftovers
    assert_equal(6, count, "found all 6 expected work loan percentages")
  end

  test "Prime Exceptionnelle Maxxes Out" do
    # config employee
    employee = return_valid_employee()

    # give correct attributes for payslips
    employee.category = "nine"
    employee.echelon = "e"
    employee.wage_scale = "a"
    employee.contract_start = "2017-07-31"

    period = Period.new(2018,1)

    pe_bonus = Bonus.create!(name: "Prime Exceptionnelle", quantity: 0.30,
        bonus_type: "percentage", maximum: 55000)
    employee.bonuses << pe_bonus
    assert_equal(1, employee.bonuses.size, "should just have PE bonus")
    payslip = Payslip.process(employee, period)

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert_equal(employee.wage, payslip.bonusbase)
    assert_equal(employee.wage, payslip.caissebase)
    assert_equal(employee.wage + 55000, payslip.cnpswage)

    earning = payslip.earnings.where(is_bonus: true).first
    assert_equal(55000, earning.amount)
  end

  test "Advances count against net Pay" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # process payslip with advance
    payslip = Payslip.process_with_advance(employee, period)

    # compute caissebase
    wage = employee.wage
    base_wage = employee.find_base_wage
    assert_equal(1, employee.years_of_service(period))

    # bonusbase (wage) + (seniority bonus (8 yrs * 0.02) * base_wage)
    exp_caisse = exp_cnps = wage
    assert_equal(exp_cnps, payslip.compute_cnpswage, "cnps same as caisse")

    # verify taxable (adds transportation)
    expected_taxable = exp_cnps + employee.transportation
    assert_equal(expected_taxable, payslip.process_taxable_wage, "taxable")
    assert_equal(0, payslip.earnings.where(is_bonus: true).count(), "no bonuses")

    # expected value
    net_pay = expected_taxable - payslip.total_tax - employee.advance_amount()
    assert_equal(net_pay, payslip.net_pay)
  end

  test "Test Vacation Pay Calculations" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    period = Period.new(2018,1)

    pre_balance = Vacation.balance(employee, period)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # remove working time for jan 22, 23, 24
    employee.work_hours.where(date: "2018-01-22").first.delete
    employee.work_hours.where(date: "2018-01-23").first.delete
    employee.work_hours.where(date: "2018-01-24").first.delete

    # Vacation add Vacation for 3 days (22, 23, 24 of jan 18)
    vac = Vacation.new(start_date: '2018-01-22', end_date: '2018-01-24')
    employee.vacations << vac

    payslip = Payslip.process(employee, period)
    vac_pay = 8481

    assert_equal(vac_pay, payslip.get_vacation_pay)
    assert_equal(1.5, payslip.vacation_earned)
    assert_equal(pre_balance - 3,  payslip.vacation_balance)
  end

  test "Loans and payments count against net Pay" do
    Date.stub :today, Date.new(2018, 2, 5) do

      # config employee
      employee = return_valid_employee()
      employee.uniondues = false;
      employee.amical = 0;
      employee.contract_start = "2017-01-01" # no senior bonus

      # new Loan
      loan = Loan.new(amount: 10000, origination: "2017-10-25",
          term: "six_month_term")
      employee.loans << loan

      # new Loan Payment in period
      loan.loan_payments.create(amount: 5000, date: "2018-01-15");

      period = Period.new(2018,1)

      # work the whole month (work hour)
      generate_work_hours employee, period

      # process payslip
      payslip = Payslip.process(employee, period)

      # Loan payment (5000) comes out of net pay
      expected_net = (employee.wage + employee.transportation) -
          payslip.total_tax - 5000
      assert_equal(expected_net, payslip.net_pay)
    end
  end

  test "Charges/Deductions against net Pay" do
    Date.stub :today, Date.new(2018, 2, 5) do

      # config employee
      employee = return_valid_employee()
      employee.uniondues = false;
      employee.amical = 0;
      employee.contract_start = "2017-01-01" # no senior bonus

      employee.charges.create!(amount: 300, note: "Coke", date: "2018-01-15")
      period = Period.new(2018,1)

      # work the whole month (work hour)
      generate_work_hours employee, period

      # process payslip
      payslip = Payslip.process(employee, period)

      # 300 Franc charge
      expected_net = (employee.wage + employee.transportation) - payslip.total_tax - 300
      assert_equal(expected_net, payslip.net_pay)
    end
  end

  test "Net Pay Cannot be Negative" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    # new Loan
    loan = Loan.new(amount: 1000000, origination: "2017-10-25",
        term: "six_month_term")
    employee.loans << loan

    # new Loan Payment in period
    loan.loan_payments.create(amount: 500000, date: "2018-01-15");

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # process payslip
    payslip = Payslip.process(employee, period)

    # The Netpay is going to be negative, verify that it will only ever be 0
    assert_equal(0, payslip.net_pay, "net pay should never be negative")
    assert_equal(1, payslip.errors.size, "should have 1 error indicating a problem with this payslip")
    assert(payslip.errors.include?(:net_pay), "should have an error for net pay")
  end

  test "Figure Pay from Departmental Charge" do
    departmental_charge = 500000
    assert_equal(303715, Payslip.compute_wage_from_departmental_charge(departmental_charge))

    departmental_charge = 1000000
    assert_equal(623654, Payslip.compute_wage_from_departmental_charge(departmental_charge))
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
