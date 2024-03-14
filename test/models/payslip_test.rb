require "test_helper"
require "logger"

class PayslipTest < ActiveSupport::TestCase

  def setup
    # Since I do some migration magic in the migrations test,
    # there are db errors unless the column information is reset.
    Payslip.reset_column_information
  end

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

  test "bonuses become earnings" do
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

    assert_equal(6, payslip.earnings.size, "must have 6 entries after processing")
  end

  test "bonuses can use caisse base" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)
    assert employee.valid?

    # create bonuses
    bonus = Bonus.new
    bonus.name = "First Bonus"
    bonus.quantity = 0.12
    bonus.percentage!
    bonus.use_caisse = false
    assert bonus.valid?
    bonus.save

    bonus2 = Bonus.new
    bonus2.name = "Second Bonus"
    bonus2.quantity = 0.05
    bonus2.percentage!
    bonus2.use_caisse = true
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

    # Find specific earnings entries
    first = payslip.earnings.where(description: "First Bonus").take
    second = payslip.earnings.where(description: "Second Bonus").take

    bonusbase = payslip.bonusbase
    caissebase = payslip.caissebase

    assert_equal(( bonusbase * bonus.quantity ).round, first.amount,
        "correct bonus for bonus")
    assert_equal(( caissebase * bonus2.quantity ).round, second.amount,
        "correct bonus amount for bonus2")
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
    charge1.charge_type = "other"
    employee.charges << charge1

    Rails.logger.debug(charge1.errors.inspect)
    assert(charge1.valid?, "charge 1 is valid")

    charge2 = Charge.new
    charge2.note = "CHARGE2"
    charge2.amount = 2000
    charge2.date = Date.today
    charge2.charge_type = "bank_transfer"
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
         assert_equal(Charge.charge_types[charge1.charge_type], ded.deduction_type)
         assert(ded.valid?, "should be valid")
         count += 1
      end

      if (ded.note == "CHARGE2")
         assert_equal(2000, ded.amount)
         assert_equal(Date.today, ded.date)
         assert_equal(Charge.charge_types[charge2.charge_type], ded.deduction_type)
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
    employee3.employment_status = "inactive"
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
    payslips = Payslip.process_all(Employee.all, period)

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

  test "payslips deduct amical automatically" do
    # have an employee
    employee = return_valid_employee()
    generate_work_hours(employee, Period.current)

    # give amical and union
    employee.amical = 3000
    employee.uniondues = true

    # process a payslip
    payslip = Payslip.process(employee, Period.current)

    # verify there are deductions for Amical and Union.
    assert_equal(1, payslip.deductions.size, "payslip should have 1 deductions")

    count = 0
    payslip.deductions.each do |ded|
      if (/amical/i =~ ded.note)
         assert_equal(3000, ded.amount)
         assert_equal(Date.today.beginning_of_month(), ded.date)
         count += 1
      end
    end

    assert_equal(1, count, "found both deductions")
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

    loan_other = Loan.new
    loan_other.employee = employee
    loan_other.origination = "2017-08-15"
    loan_other.amount = 10000
    loan_other.comment = "aug loan 2"

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

  test "payslips only run for full, part, or temp employees (and leave)" do
    employee = return_valid_employee()
    employee.employment_status = "inactive"

    jan = Period.new(2018,1)
    generate_work_hours employee, Period.new(2018, 1)

    nil_payslip = Payslip.process(employee, jan)
    refute(nil_payslip, "should not process anything for a leave employee")
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

    hl = Holiday.new(name: "Christmas", date: "2017-12-25")
    assert(hl.save)

    # work some of the month
    hours = {
      "2017-12-01" => {hours: 8}
    }
    WorkHour.update(employee, hours)
    payslip = Payslip.process(employee, period)

    assert_equal(108580, employee.wage)
    assert_equal(5008, employee.daily_rate.round)
    # including 12/25
    days_worked = payslip.days_worked
    assert_equal(2, days_worked)
    workdays = employee.workdays_per_month(period)
    assert_equal(21, workdays)

    # The full-time employee is paid their wage, times
    # the number of days worked times their daily rate
    assert_equal( (days_worked * employee.daily_rate).round, payslip.base_pay)

    # Work the whole month
    #hours = {
    #  "2017-12-01" => {hours: 8},
    #  "2017-12-25" => {hours: 0}
    #}
    #WorkHour.update(employee, hours)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert(employee.paid_monthly?, "emp is monthly")
    assert(payslip.employee.paid_monthly?, "pemp is monthly")

    assert_equal(21, employee.workdays_per_month(period))
    assert_equal(21, WorkHour.days_worked(employee, period))

    assert(payslip.worked_full_month?, "now has worked whole month")
    assert_equal(employee.wage, payslip.base_pay)

    assert_equal((payslip.basepay + payslip.overtime_earnings).ceil,
        payslip.earnings.where(is_bonus: false).sum(:amount).ceil)
  end

  test "Union dues now in total tax" do
    period = Period.new(2017,12)
    employee = return_valid_employee()

    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    assert_equal(employee.union_dues_amount, payslip.union_dues)

    refute(payslip.deductions.find_by(note: Employee::UNION),
        "should not find deduction anymore")

    # Note: union_dues in added to total_tax
    tax = Tax.compute_taxes(employee, payslip.taxable, payslip.cnpswage)
    assert_equal(payslip.total_tax, tax.total_tax + employee.union_dues_amount)
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
    #assert_nil(payslip.hours)
    assert_equal(48.0, payslip.hours)

    assert_equal(6, payslip.days_worked(), "worked 6 days")
    assert_equal(48, payslip.hours_worked(), "worked 48 hours")
    assert(employee.paid_monthly?, "employee is paid monthly")
    refute(payslip.worked_full_month?, "worked partial month in jan18")

    # compute bonusbase
    assert_equal(79475, employee.wage, "wage is expected")
    assert_equal(3672, employee.daily_rate.round, "daily rate is computed")
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
    #assert_nil(payslip.days)
    assert_equal(23.0, payslip.days)

    assert(payslip.worked_full_month?)
    refute(employee.paid_monthly?)

    # compute bonusbase
    assert_equal(79475, employee.wage)
    assert_equal(84456, payslip.compute_bonusbase)
  end

  test "Overtime Rates" do
    employee = return_valid_employee()
    period = Period.new(2018,1)

    employee.hours_day = 8
    employee.days_week = "five"
    employee.category = 6
    employee.echelon = "g"
    employee.wage = "117215"
    assert_equal(117215, employee.wage)

    assert_equal(811, employee.otrate, "OT rate is correct")
    assert_equal(879, employee.ot2rate, "OT2 Rate is correct")
    assert_equal(946, employee.ot3rate, "OT3 Rate is correct")
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
    assert_equal(459, employee.hourly_rate.round, "hourly rate is computed")
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
    assert_equal(640, payslip.overtime2_rate)
    assert_equal(689, payslip.overtime3_rate)

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(492, employee.hourly_rate.round, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate.round, "daily rate is computed")

    # 85300 + OT hours (2 * (hourlyrate * 1.2)) or
    assert_equal(86480, payslip.compute_bonusbase, "proper bonus base for 2 OT1")
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
    # full month, except 10 hours on 1/2
    hours = {
      '2018-01-02' => {hours: 17},
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
    assert_equal(640, payslip.overtime2_rate)
    assert_equal(689, payslip.overtime3_rate)

    assert_equal(23.0, payslip.days)
    assert_equal(193.0, payslip.hours)

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(492, employee.hourly_rate.round, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate.round, "daily rate is computed")

    expected = (85300 + (8 * (employee.hourly_rate * 1.2).round) +
        (1 * (employee.hourly_rate * 1.3).round)).ceil
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

    assert_equal(23.0, payslip.days)
    assert_equal(203.0, payslip.hours)

    assert_equal(8, payslip.overtime_hours)
    assert_equal(8, payslip.overtime2_hours)
    assert_equal(3, payslip.overtime3_hours)

    assert_equal(590, payslip.overtime_rate)
    assert_equal(640, payslip.overtime2_rate)
    assert_equal(689, payslip.overtime3_rate)

    # compute bonusbase
    assert_equal(85300, employee.wage, "wage is expected")
    assert_equal(employee.wage, payslip.base_pay, "base_pay is good")
    assert_equal(492, employee.hourly_rate.round, "hourly rate is computed")
    assert_equal(3936, employee.daily_rate.round, "daily rate is computed")

    expected = (
        85300 + (8 * (employee.otrate)) +
          (8 * (employee.ot2rate)) + (3 * (employee.ot3rate))
    ).ceil

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
    bonusbase = payslip.bonusbase
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
    exp_cnps_w_pdc = (exp_cnps + (bonusbase * 0.05).round).ceil # PDC Bonus
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
    exp_pdc_pe = (exp_cnps + (bonusbase * 0.05).round +
          (bonusbase * 0.30).round).ceil # PDC + PE Bonus
    assert_equal(exp_pdc_pe, payslip.compute_cnpswage, "cnps with pdc + pe")

    # another bonus
    spot_bonus = Bonus.create!(name: "Spot Bonus", quantity: 10000,
        bonus_type: "fixed")
    employee.bonuses << spot_bonus
    assert_equal(3, employee.bonuses.size)
    payslip = Payslip.process(employee, period)

    # verify cnps
    exp_triple_bonus = (exp_cnps + (bonusbase * 0.05).round +
          (bonusbase * 0.30).round + 10000).ceil # PDC + PE Bonus
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

    assert_equal(employee.hourly_rate.round, payslip.hourly_rate.round)
    assert_equal(employee.daily_rate.round, payslip.daily_rate.round)

    assert_equal(416, payslip.communal)
    assert_equal(611, payslip.cac)
    assert_equal(0, payslip.cac2)
    assert_equal(5460, payslip.cnps)
    assert_equal(6108, payslip.proportional)
    assert_equal(1950, payslip.crtv)
    assert_equal(1500, payslip.ccf)
    assert_equal(150000, payslip.roundedpay)

    exp_total_tax = payslip.communal + payslip.cac +
        payslip.cac2 + payslip.cnps + payslip.proportional +
          payslip.crtv + payslip.ccf

    assert_equal(exp_total_tax, payslip.total_tax)

    # This is the raw number
    assert_equal(new_exp_taxable - exp_total_tax - employee.amical, payslip.raw_net_pay)
    # This is rounded.
    assert_equal(Payslip.cfa_round(new_exp_taxable - exp_total_tax - employee.amical), payslip.net_pay)

    # Total Pay
    total_pay = payslip.taxable - (payslip.total_tax) +
        payslip.union_dues
    assert_equal(total_pay, payslip.salaire_net, "total pay correct")
  end

  test "Salaire Net" do
    advance_amt = 30000

    # config employee
    employee = return_valid_employee()
    period = Period.new(2018,1)

    assert_equal(0, employee.charges.count, "no charges")

    # work the whole month (work hour)
    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    orig_total_pay = payslip.taxable - (payslip.total_tax)
    assert_equal(orig_total_pay, payslip.salaire_net, "total pay correct")

    # sal advance
    Charge.create!(employee: employee, amount: advance_amt, charge_type: Charge.charge_types[:advance], date: "2018-01-15", note: "Salary Advance")
    assert_equal(1, employee.charges.count, "now has charge")

    # Re process
    payslip = Payslip.process(employee, period)
    assert_equal(advance_amt, payslip.salary_advance, "correctly set");

    # Total Pay
    total_pay = payslip.taxable - (payslip.total_tax)
    assert_equal(orig_total_pay, total_pay, "total pay did not change")
    assert_equal(total_pay, payslip.salaire_net, "total pay correct")
  end

  test "CFA Round" do
    num = 123456
    assert_equal(123460, Payslip.cfa_round(num))

    num = 123466
    assert_equal(123470, Payslip.cfa_round(num))

    num = 123599
    assert_equal(123600, Payslip.cfa_round(num))
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
    # 173.333 avg hours per month 
    # 40 / 173.333 is 23.08%
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
    count = 0
    assert_equal(1, payslip.work_loan_percentages.size, "should only be one")
    assert_equal(1, payslip.work_loan_percentages.first.percentage, "should be for 100%")
    assert_equal(admin_dept.id, payslip.work_loan_percentages.first.department_id,
        "should be for admin dept")
  end

  test "Worked partial month computes work loans properly" do
    # Basically
    #  work 15 days in a month.
    #  the work loan percentage should be based off
    #  that 15 days * 8 hours.
    #  not the 173 hours.
    #  Verify that.
    #  Just like the other tests.

    # config employee
    lss_dept = departments :LSS
    admin_dept = departments :Admin

    employee = return_valid_employee()
    employee.department_id = lss_dept.id

    period = Period.new(2018,1)
    start_date = period.start
    finish_date = period.finish

    # Loan 2 days
    wl = WorkLoan.new
    wl.date = "2018-01-15"
    wl.department = departments :Admin
    wl.hours = 8
    employee.work_loans << wl
    wl = WorkLoan.new
    wl.date = "2018-01-16"
    wl.department = departments :Admin
    wl.hours = 8
    employee.work_loans << wl

    # work the whole month (work hour)
    generate_work_hours employee, period

    # remove working time for vacation period
    employee.work_hours.where(date: "2018-01-22").first.delete
    employee.work_hours.where(date: "2018-01-23").first.delete
    employee.work_hours.where(date: "2018-01-24").first.delete
    employee.work_hours.where(date: "2018-01-25").first.delete
    employee.work_hours.where(date: "2018-01-26").first.delete
    employee.work_hours.where(date: "2018-01-29").first.delete
    employee.work_hours.where(date: "2018-01-30").first.delete
    employee.work_hours.where(date: "2018-01-31").first.delete

    vac = Vacation.new(start_date: '2018-01-22', end_date: '2018-01-31')
    employee.vacations << vac
    assert_equal(8, vac.days, "should be 8 days between 22/1/18 and 13/1/18")
    employee.vacations << vac

    payslip = Payslip.process(employee, period)

    assert_equal(15, payslip.days_worked, "worked 15 days")

    # Verify that I have work loan percentages now.
    # Worked 15 days (15 * 8 = 120 hours).
    # 16 / 120 hours is 13.33%, then the rest is for lss
    count = 0
    payslip.work_loan_percentages.all.each do |wlp|
      if (wlp.department_id == admin_dept.id)
        assert_equal(13.33, (wlp.percentage * 100).round(2))
        count += 1
      elsif (wlp.department_id == lss_dept.id)
        assert_equal(86.67, (wlp.percentage * 100).round(2))
        count += 1
      else
        # we shouldn't find any others
        count += 1
      end
    end
    assert_equal(2, count, "found two items")
  end

  test "Test Many Departments" do
    admin_dept = departments :Admin
    av_dept = departments :Aviation
    ctc_dept = departments :CTC
    rfis_dept = departments :RFIS
    cam_dept = departments :Cam
    lss_dept = departments :LSS

    # out of 173.33 hours
    to_create = {
      admin_dept => 16, #  9.231%
      av_dept => 40,    # 23.077%
      ctc_dept => 32,   # 18.462%
      rfis_dept => 8,   #  4.615%
      cam_dept => 64,   # 36.923%
    }
    # total: 162 hours | 92.308%

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
        assert_equal(8.7, (wlp.percentage * 100).round(2))
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

  test "If you are on vacation the whole month, you get nothing, not even bonuses" do
    # https://media.giphy.com/media/nygbstO5bEJmE/giphy.gif
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    period = Period.new(2018,1)

    prev_vac_pay_bal = 75665
    prev_vac_bal = 24.3
    set_previous_vacation_balances(employee, period, prev_vac_pay_bal, prev_vac_bal)

    # Vacation the whole month (maybe read a good book?)
    vac = Vacation.new(start_date: period.start, end_date: period.finish)
    employee.vacations << vac

    payslip = Payslip.process(employee, period)

    assert_equal(0, payslip.gross_pay, "gross should be zero")
    assert_equal(0, payslip.net_pay, "net should be zero")

    # You don't accrue vacation while you are off.
    assert_equal(0, payslip.vacation_earned, "correct days earned")
    assert_equal(0, payslip.vacation_pay_earned, "correct pay earned")

    # although it should track the vacation pay and days used for reporting.
    prev_payslip = payslip.previous
    assert(prev_payslip, "previous slip exists")

    assert_equal(prev_vac_bal, prev_payslip.vacation_balance)
    assert_equal(prev_vac_pay_bal, prev_payslip.vacation_pay_balance)
    assert_equal(payslip.taxable.fdiv(SystemVariable.value(:vacation_pay_factor).to_f), payslip.vacation_pay_earned)

    cur_bal = prev_payslip.vacation_balance + payslip.vacation_earned
    cur_pay_bal = prev_payslip.vacation_pay_balance + payslip.vacation_pay_earned

    vpu = (payslip.vacation_daily_rate * vac.days).round

    assert_equal(vac.days, payslip.vacation_used, "correct days used")
    assert_equal(vpu, payslip.vacation_pay_used, "correct pay used")

    assert_equal(
        prev_vac_bal + payslip.vacation_earned - vac.days,
        payslip.vacation_balance, "correct balance after usage")
    assert_equal(
        (payslip.vacation_balance * payslip.vacation_daily_rate).round,
        payslip.vacation_pay_balance, "correct balance after usage")
  end

  test "Test Vacation Pay and Balance Calculations" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    period = Period.new(2018,1)

    pre_balance = Vacation.balance(employee, period.previous)

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

    days_worked = WorkHour.days_worked(employee, period)
    assert_equal(20, days_worked)
    working_days_in_dec = employee.workdays_per_month(period)
    assert_equal(23, working_days_in_dec)
    assert_equal(3, Vacation.days_used(employee, period))

    vac_pay_used = ( payslip.vacation_daily_rate * vac.days ).round
    vac_pay_used_other = ( Vacation.vacation_daily_rate(employee) * vac.days ).round

    assert_equal(0.0, payslip.period_suppl_days, "receives no supplemental days")

    # these should be the same.
    assert_equal(vac_pay_used, vac_pay_used_other)
    assert_equal(vac.days, payslip.vacation_used)

    # FIXME, this really needs to be fixed. (byee 29-Oct -- maybe okay?)
    assert_equal(vac_pay_used, payslip.vacation_pay_used)

    assert_equal(1.5, payslip.vacation_earned)
    assert_equal(pre_balance - 3 + payslip.vacation_earned, payslip.vacation_balance)
  end

  # Could this test *be* any more complicated?
  # Basically let's run a vacation that spans 3 months
  # and ensure each slip along the way is copacetic.
  #
  # Summary:
  # Vacataion between Jan 22 and March 03 2018, inclusive (30 days)
  # January: 8 days
  # February: 20 days (all)
  # March: 2 days
  test "Les grandes grandes vacances" do
    dec_starting_vacation_days = 35

    # config employee
    employee = return_valid_employee()
    employee.uniondues = true;
    employee.amical = 3000;
    employee.contract_start = "1992-01-01"

    period = Period.new(2018,1)
    set_previous_vacation_balances(employee, period, 286978, dec_starting_vacation_days)

    # I do what I want!
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: 2017, month: 12
    lpp.save!

    assert_equal(period.month, LastPostedPeriod.current.month, "We're in the right period")
    assert_equal(period.year, LastPostedPeriod.current.year, "We're in the right period!")

    payslip = Payslip.process(employee, period)

    # work the whole month (work hour)
    generate_work_hours employee, period
    # pre_balance = Vacation.balance(employee, period)

    # remove working time for jan 22 - jan 31
    (22..31).each do |day|
      #Rails.logger.error("deleting 2018-01-#{day}")
      employee.work_hours.where(date: "2018-01-#{day}").first.delete
    end

    #employee.work_hours.where(date: "2018-01-23").first.delete
    #employee.work_hours.where(date: "2018-01-24").first.delete
    #employee.work_hours.where(date: "2018-01-25").first.delete
    #employee.work_hours.where(date: "2018-01-26").first.delete
    #employee.work_hours.where(date: "2018-01-29").first.delete
    #employee.work_hours.where(date: "2018-01-30").first.delete
    #employee.work_hours.where(date: "2018-01-31").first.delete

    # Vacation add Vacation for Jan 22 until March 03
    vac = Vacation.new(start_date: '2018-01-22', end_date: '2018-03-03')
    employee.vacations << vac
    assert_equal(30, vac.days, "should be 30 days between 22/1/18 and 3/3/18")

    # January (8 Days vacation)
    payslip = Payslip.process(employee, period)
    assert_equal(employee.workdays_per_month(period) - 8, payslip.days,
        "not paid for 8 vacation days in January")
    refute(payslip.on_vacation_entire_period?, "not on vacation all of jan")

    # Verify payslip vacation totals are correct for Jan
    jan_days_earned = payslip.vacation_earned
    jan_pay_earned = payslip.vacation_pay_earned

    period_suppl_days = payslip.period_suppl_days
    assert_equal((10/12.0).round(3), payslip.period_suppl_days.round(3), "correct value")

    assert_equal(
        (period_suppl_days + Payslip::STANDARD_DAYS_EARNED).round(2),
        jan_days_earned.round(2),
        "earning is correct during transfer"
    )

    jan_days_used = payslip.vacation_used
    assert_equal(0, jan_days_used, "0 vac days in Jan, they will be applied in Feb")

    assert_equal(0, payslip.vacation_pay_used, "no vacation pay used in Jan")

    jan_days_balance = payslip.vacation_balance
    jan_balance = dec_starting_vacation_days + jan_days_earned - jan_days_used
    assert_equal(jan_balance, jan_days_balance,
        "FIXME: Jan balance is correct (11.5 was already added in the pre_balance)")
    assert_equal(jan_balance, payslip.vacation_balance, "ps value is correct as well")

    # Advance to February (20 Days Vacation - (entire working month))
    LastPostedPeriod.post_current
    period = LastPostedPeriod.current

    assert_equal(2, period.month, "We're in the right period")
    assert_equal(2018, period.next.year, "We're in the right period!")
    assert_equal(period.month, LastPostedPeriod.current.month, "We're in the right period")
    assert_equal(period.next.year, LastPostedPeriod.current.year, "We're in the right period!")
    assert_equal({}, WorkHour.total_hours(employee, period), "no hours worked in Feb")

    payslip = Payslip.process(employee, period)
    assert(payslip.on_vacation_entire_period?, "on vacation all of feb")

    vdays = Vacation.days_used(employee, period)
    wdays = employee.workdays_per_month(period)
    assert(vdays >= wdays, "feb is a wash yo")

    assert_equal(0, payslip.days, "no days in February")
    assert_equal(0, payslip.gross_pay, "not paid for February")
    assert_equal(0, payslip.net_pay, "not paid for February")

    feb_days_earned = payslip.vacation_earned
    assert_equal(0, feb_days_earned,
        "Zero days in Feb, because off during that month")

    # Verify payslip vacation totals are correct for Feb
    # (dec starting balance + jan earned vac pay /
    #     dec_starting days balance + jan days + feb_days) * days
    vac_pay_earned = ( payslip.vacation_daily_rate * vac.days ).round

    # FIXME thi needs to be fixed.
    assert_equal(vac_pay_earned, payslip.vacation_pay_used, "all pay received in Feb")

    # There is this other method, which should return the same result.
    vac_pay_earned_other = ( Vacation.vacation_daily_rate(employee) * vac.days ).round
    assert_equal(vac_pay_earned, vac_pay_earned_other, "these should be the same")

    feb_days_used = payslip.vacation_used
    assert_equal(30, feb_days_used, "30 vac days in Feb")

    feb_days_balance = payslip.vacation_balance
    feb_balance = jan_balance - feb_days_used + feb_days_earned

    assert_equal(feb_balance, feb_days_balance, "Feb balance is correct")

    # Advance to March (2 Days Vacation)
    LastPostedPeriod.post_current
    period = LastPostedPeriod.current

    generate_work_hours_for_range(employee, Date.new(2018,3,4), Date.new(2018,3,31))

    payslip = Payslip.process(employee, period)
    assert_equal(employee.workdays_per_month(period) - 2, payslip.days,
        "not paid for 2 vacation days in March")
    refute(payslip.on_vacation_entire_period?, "not on vacation all of mar")

    # Verify payslip vacation totals are correct for Mar
    assert_equal(0, payslip.vacation_pay_used, "no pay received in Mar")

    mar_days_earned = payslip.vacation_earned
    mar_suppl_days_earned = payslip.period_suppl_days
    assert_equal((1.5 + mar_suppl_days_earned).round(2), mar_days_earned.round(2), "earning is correct")

    mar_days_used = payslip.vacation_used
    assert_equal(0, mar_days_used, "2 vac days in Mar, but applied in Feb")

    mar_days_balance = payslip.vacation_balance
    mar_balance = feb_balance - mar_days_used + mar_days_earned
    assert_equal(mar_balance, mar_days_balance, "Mar balance is correct")
  end

  test "Re-processing Payslips Returns the same Vacation Balance" do
    Date.stub :today, Date.new(2018, 2, 5) do
      # config employee
      employee = return_valid_employee()
      employee.uniondues = false;
      employee.amical = 0;
      employee.first_day = "2017-12-01"
      employee.contract_start = "2017-12-01"

      period = Period.new(2018,1)

      # work the whole month (work hour)
      generate_work_hours employee, period

      correct_vacation_balance = 3.0

      # process payslip
      payslip = Payslip.process(employee, period)
      assert_equal(correct_vacation_balance.round(2), payslip.vacation_balance.round(2),
          "vac balance is correct")

      # process payslip again again
      payslip = Payslip.process(employee, period)
      assert_equal(correct_vacation_balance.round(2), payslip.vacation_balance.round(2),
          "doesn't change")
    end
  end

  test "Employee who doesn't accrue vacation doesn't accrue vacation" do
    employee = return_valid_employee()
    employee.accrue_vacation = false
    employee.save
    refute(employee.accrue_vacation)

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # process payslip
    payslip = Payslip.process(employee, period)
    assert_equal(0.00, payslip.vacation_balance.round(2), "no vacation balance")
    assert_equal(0.00, payslip.vacation_pay_balance.round(2), "no vacation balance")
  end

  test "Employee not accruing vacation who has balance will show 0 on payslips" do
    employee = return_valid_employee
    employee.accrue_vacation = false
    employee.contract_start = "2008-01-01" # set for supplemental days
    employee.save
    refute(employee.accrue_vacation)

    period = Period.new(2018,3)

    previous_pay_balance = 245345
    previous_balance = 33
    set_previous_vacation_balances(employee, period, previous_pay_balance, previous_balance)
    generate_work_hours(employee, period)

    payslip = Payslip.process(employee, period)

    # Don't earn vacation now.
    assert_equal(0, payslip.calc_vacation_pay_earned, "no vac earned")
    assert_equal(0, payslip.vacation_pay_earned, "no vac earned")
    assert_equal(0, payslip.vacation_earned, "no vac days earned")
  end

  test "Employee who didn't accrue vacation starts to accrue" do
    employee = return_valid_employee
    employee.accrue_vacation = false
    employee.contract_start = "2018-03-01" # new employee
    employee.first_day = "2018-03-01" # new employee
    employee.save
    refute(employee.accrue_vacation)

    period = Period.new(2018,3) # first month of work
    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)

    refute(payslip.vac_accrue, "the ps knows if vac was accrued this period")
    assert_equal(0, payslip.vacation_earned)
    assert_equal(0, payslip.vacation_balance)
    assert_equal(0, payslip.vacation_pay_earned)
    assert_equal(0, payslip.vacation_pay_balance)

    employee.accrue_vacation = true;
    employee.save;

    next_period = period.next
    generate_work_hours(employee, next_period)
    payslip = Payslip.process(employee, next_period)

    assert(payslip.vac_accrue, "the ps knows if vac was accrued this period")
    assert_equal(1.5, payslip.vacation_earned)
    assert_equal(1.5, payslip.vacation_balance)
    assert(payslip.vacation_pay_balance > 0, "what you earn is the balance")
  end

  test "Loans and payments count against net Pay" do
    Date.stub :today, Date.new(2018, 2, 5) do

      # config employee
      employee = return_valid_employee()
      employee.uniondues = false;
      employee.amical = 0;
      employee.contract_start = "2017-01-01" # no senior bonus

      # new Loan
      loan = Loan.new(amount: 10000, origination: "2017-10-25")
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
      assert_equal(Payslip.cfa_round(expected_net), payslip.net_pay)
    end
  end

  test "Misc Payments are counted (before tax)" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    # Add a payment to verify is there.
    pmnt = MiscPayment.new
    pmnt.amount = 50000
    pmnt.note = "Testing"
    pmnt.date = "2018-01-15"
    pmnt.before_tax = true
    employee.misc_payments << pmnt
    assert(pmnt.valid?, "payment should be valid and not with these errors #{pmnt.errors.messages.inspect}")
    assert(pmnt.save, "payment is saved")

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # process payslip
    payslip = Payslip.process(employee, period)

    # compute caissebase
    wage = employee.wage
    base_wage = employee.find_base_wage

    exp_caisse = wage
    exp_cnps = exp_caisse + pmnt.amount
    assert_equal(exp_cnps, payslip.compute_cnpswage, "cnps same as caisse")

    # verify taxable (adds transportation)
    expected_taxable = exp_cnps + employee.transportation
    assert_equal(expected_taxable, payslip.process_taxable_wage, "taxable")
    assert_equal(0, payslip.earnings.where(is_bonus: true).count(), "no bonuses")

    # expected value
    net_pay = expected_taxable - payslip.total_tax
    assert_equal(net_pay, payslip.raw_net_pay)
    assert_equal(Payslip.cfa_round(net_pay), payslip.net_pay)
  end

  test "After Tax Misc Payments" do
    # config employee
    employee = return_valid_employee()
    # simply payslip
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    period = Period.new(2018,1)
    bonus = 6000

    # Add a payment to verify is there.
    pmnt = MiscPayment.new
    pmnt.amount = bonus
    pmnt.note = "Testing"
    pmnt.before_tax = false
    pmnt.date = period.start
    employee.misc_payments << pmnt
    assert(pmnt.valid?, "payment should be valid and not with these errors #{pmnt.errors.messages.inspect}")
    assert(pmnt.save, "payment is saved")
    refute(pmnt.before_tax, "payment is after tax")

    generate_work_hours employee, period
    payslip = Payslip.process(employee, period)

    # Figure out if bonus was paid correctly
    net_pay = payslip.taxable - payslip.total_tax + bonus
    assert_equal(net_pay, payslip.raw_net_pay)
    assert_equal(Payslip.cfa_round(net_pay), payslip.net_pay)
  end

  test "Charges/Deductions against net Pay" do
    Date.stub :today, Date.new(2018, 2, 5) do

      # config employee
      employee = return_valid_employee()
      employee.uniondues = false;
      employee.amical = 0;
      employee.contract_start = "2017-01-01" # no senior bonus

      employee.charges.create!(amount: 300, note: "Coke",
          charge_type: "other", date: "2018-01-15")
      period = Period.new(2018,1)

      # work the whole month (work hour)
      generate_work_hours employee, period

      # process payslip
      payslip = Payslip.process(employee, period)

      # 300 Franc charge
      expected_net = (employee.wage + employee.transportation) - payslip.total_tax - 300
      assert_equal(expected_net, payslip.raw_net_pay)
      assert_equal(Payslip.cfa_round(expected_net), payslip.net_pay)
    end
  end

  test "Net Pay Cannot be Negative" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    # new Loan
    loan = Loan.new(amount: 1000000, origination: "2017-10-25")
    employee.loans << loan

    # new Loan Payment in period
    loan.loan_payments.create(amount: 500000, date: "2018-01-15")

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # process payslip
    payslip = Payslip.process(employee, period)

    # The Netpay is going to be negative, verify that it will only ever be 0
    assert(payslip.net_pay < 0, "net pay should never be negative")
    assert_equal(1, payslip.errors.size, "should have 1 error indicating a problem with this payslip")
    assert(payslip.errors.include?(:net_pay), "should have an error for net pay")
  end

  test "Non-Non-RFIS employees get automatic deduction" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false
    employee.amical = 0
    employee.location = "bro"
    employee.contract_start = "2017-01-01" # no senior bonus
    assert_equal("bro", employee.location, "employee works in BRO")

    period = Period.new(2018,1)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # process payslip
    payslip = Payslip.process(employee, period)

    # The Netpay is going to be negative, verify that it will only ever be 0
    assert_equal(0, payslip.net_pay, "net pay should be zero")
    assert_equal(0, payslip.errors.size, "should not have errors regarding 0 pay")

    # Deductions?
    deduction = payslip.deductions.find_by(deduction_type: Charge.charge_types["location_transfer"])
    assert_equal("Salary Transfer to BRO", deduction.note)
    assert(deduction, "should have deduction for transfer")
    assert_equal(72410, deduction.amount, "should have deduction for transfer")

    # Rerun in GNRO
    employee.location = "gnro"
    assert_equal("gnro", employee.location, "employee works in GNRO")
    payslip = Payslip.process(employee, period)

    # Deductions?
    deduction = payslip.deductions.find_by(deduction_type: Charge.charge_types["location_transfer"])
    assert_equal("Salary Transfer to GNRO", deduction.note)
    assert(deduction, "should have deduction for transfer")
    assert_equal(72410, deduction.amount, "should have deduction for transfer")

    # Rerun in CTC
    employee.location = "nonrfis"
    assert_equal("nonrfis", employee.location, "employee works at CTC")
    payslip = Payslip.process(employee, period)

    # Deductions?
    assert_equal(72410, payslip.net_pay, "net pay should be zero")
    assert_equal(0, payslip.errors.size, "should not have errors regarding 0 pay")
    deduction = payslip.deductions.find_by(deduction_type: Charge.charge_types["location_transfer"])
    refute(deduction)
  end

  test "Figure Pay from Departmental Charge" do
    departmental_charge = 500000
    assert_equal(303715, Payslip.compute_wage_from_departmental_charge(departmental_charge))

    departmental_charge = 1000000
    assert_equal(623654, Payslip.compute_wage_from_departmental_charge(departmental_charge))
  end

  test "Pay Calculation for Various Days" do
    employee = return_valid_employee()
    period = Period.new(2018,2) # Feb 2018 has 20 working days.
    assert_equal(0, WorkHour.days_worked(employee, period))

    generate_work_hours employee, period
    assert_equal(20, WorkHour.days_worked(employee, period))

    # Vacation for 5 days. Go Camping?
    vac = Vacation.new(start_date: '2018-02-05', end_date: '2018-02-09')
    employee.vacations << vac

    days_worked = WorkHour.days_worked(employee, period)
    assert_equal(15, days_worked)

    hours = {
      "2018-02-21" => {hours: 0.0}
    }
    WorkHour.update(employee, hours)

    days_worked = WorkHour.days_worked(employee, period)
    assert_equal(14, days_worked)

    days_not_worked = employee.workdays_per_month(period) - days_worked
    assert_equal(6, days_not_worked)

    payslip = Payslip.process(employee, period)
    assert_equal(days_worked, payslip.days_worked)

    daily_rate = employee.daily_rate

    assert_equal(daily_rate, employee.daily_rate)
    assert_equal((daily_rate * days_worked).round, payslip.base_pay)
  end

  test "1 day in 23 day month is not less than 0" do
    employee = return_valid_employee()
    period = Period.new(2018,5) # May 2018 has 23 working days.
    assert_equal(0, WorkHour.days_worked(employee, period))

    generate_work_hours employee, period
    assert_equal(23, WorkHour.days_worked(employee, period))

    hours = {
      "2018-05-01" => {hours: 0.0},
      "2018-05-02" => {hours: 0.0},
      "2018-05-03" => {hours: 0.0},
      "2018-05-04" => {hours: 0.0},
      "2018-05-07" => {hours: 0.0},
      "2018-05-08" => {hours: 0.0},
      "2018-05-09" => {hours: 0.0},
      "2018-05-10" => {hours: 0.0},
      "2018-05-11" => {hours: 0.0},
      "2018-05-14" => {hours: 0.0},
      "2018-05-15" => {hours: 0.0},
      "2018-05-16" => {hours: 0.0},
      "2018-05-17" => {hours: 0.0},
      "2018-05-18" => {hours: 0.0},
      "2018-05-21" => {hours: 0.0},
      "2018-05-22" => {hours: 0.0},
      "2018-05-23" => {hours: 0.0},
      "2018-05-24" => {hours: 0.0},
      "2018-05-25" => {hours: 0.0},
      "2018-05-29" => {hours: 0.0},
      "2018-05-30" => {hours: 0.0},
      "2018-05-31" => {hours: 0.0}
    }
    # Still working the 28th
    WorkHour.update(employee, hours)

    days_worked = WorkHour.days_worked(employee, period)
    assert_equal(1, days_worked, "worked the 28th")

    payslip = Payslip.process(employee, period)
    assert_equal(days_worked, payslip.days)
    daily_rate = employee.daily_rate

    days_not_worked = employee.workdays_per_month(period) - days_worked
    assert_equal(22, days_not_worked, "missed 22 days, slacker")

    assert((employee.wage - (days_not_worked * daily_rate)).round < 0,
        "this employee would've made less than 0")
    assert_equal(3392, payslip.base_pay, "but they didn't")
  end

  test "22 days in 23 day month is not greater than wage" do
    employee = return_valid_employee()
    period = Period.new(2018,5) # May 2018 has 23 working days.
    assert_equal(0, WorkHour.days_worked(employee, period))

    generate_work_hours employee, period
    assert_equal(23, WorkHour.days_worked(employee, period))

    hours = {
      "2018-05-02" => {hours: 0.0},
    }

    # Still working the 28th
    WorkHour.update(employee, hours)

    days_worked = WorkHour.days_worked(employee, period)
    assert_equal(22, days_worked, "22 days")

    payslip = Payslip.process(employee, period)
    assert_equal(days_worked, payslip.days)
    daily_rate = employee.daily_rate

    days_not_worked = employee.workdays_per_month(period) - days_worked
    assert_equal(1, days_not_worked, "missed 22 days, slacker")

    wage = employee.wage
    assert((days_worked * daily_rate).round > wage,
        "this employee would've made more than wage")
    assert_equal(wage, payslip.base_pay, "but they didn't")
  end

  test "multiple vacations compute correctly" do
    # Two vacations (10-2-18 -> 10/3/18 and 10/16/18 - 11/18/18)
    period = Period.new(2018,10)

    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    pre_balance = 23.3
    pre_pay_balance = 294834
    set_previous_vacation_balances(employee, period, pre_pay_balance, pre_balance)

    # work the whole month (work hour)
    generate_work_hours employee, period

    # Reconfig for Vacation for 2 days (02 and 03 of oct 18)
    employee.work_hours.where(date: "2018-10-02").first.delete
    employee.work_hours.where(date: "2018-10-03").first.delete
    vac1 = Vacation.new(start_date: '2018-10-02', end_date: '2018-10-03')
    employee.vacations << vac1

    # Reconfig for Vacation for 3 days (16,17,18 of oct 18)
    employee.work_hours.where(date: "2018-10-16").first.delete
    employee.work_hours.where(date: "2018-10-17").first.delete
    employee.work_hours.where(date: "2018-10-18").first.delete
    vac2 = Vacation.new(start_date: '2018-10-16', end_date: '2018-10-18')
    employee.vacations << vac2

    vacs = Vacation.for_period(period)
    assert_equal(2, vacs.count, "should be 2 vacations")
    assert_equal(5, Vacation.days_used(employee, period), "Should have used 5 days")
    working_days_in_period = employee.workdays_per_month(period)
    assert_equal(23, working_days_in_period)

    payslip = Payslip.process(employee, period)
    set_previous_vacation_balances(employee, period, 349854, 23.3)

    # 5 days of vacation.
    days_worked = WorkHour.days_worked(employee, period)
    assert_equal(18, days_worked) # working days less vacation days = 18
    assert_equal(5, Vacation.days_used(employee, period))

    assert_equal(1.5, payslip.vacation_earned)
    assert_equal(5, payslip.vacation_used)

    assert_equal(pre_balance - payslip.vacation_used + payslip.vacation_earned,
        payslip.vacation_balance)

    vac1pay = vac1.vacation_pay
    vac2pay = vac2.vacation_pay
    both_vac_pay = vac1pay + vac2pay

    # Test pay
    assert_equal(4129, payslip.vacation_pay_earned, "pay balance is correct")

    # Vac daily rate
    assert_equal(3113.79, payslip.vacation_daily_rate.round(2), "daily rate is okay")

    # FIXME this really needs to be fixed.
    assert_equal(both_vac_pay, payslip.vacation_pay_used, "pay balance is correct")

    assert_equal((pre_balance - payslip.vacation_used + payslip.vacation_earned + payslip.period_suppl_days),
        payslip.vacation_balance, "New vacation balance is correct")

    assert_equal((payslip.vacation_daily_rate * payslip.vacation_balance).round,
        payslip.vacation_pay_balance, "pay balance is correct")
  end

  test "Vacation.balance should work consistently" do
    # config employee
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2017-01-01" # no senior bonus

    period = LastPostedPeriod.current

    pre_pre_balance = Vacation.balance(employee, period.previous)
    assert_equal(0, pre_pre_balance) # nothing set in payslip

    pre_balance = 23.3
    pre_pay_balance = 294834

    previous_period = period.previous

    # PUT THIS BACK IN?? FIXME WHAT IS THIS TESTING?
    #generate_work_hours(employee, previous_period)
    previous_payslip = Payslip.process(employee, previous_period)
    assert(previous_payslip.valid?)

    previous_payslip.vacation_balance = pre_balance
    previous_payslip.vacation_pay_balance = pre_pay_balance

    assert(previous_payslip.save)

    # Once I have a previous balance, this should be used.
    assert_equal(pre_balance, Vacation.balance(employee, period.previous))
  end

  test "Vacation period days accure with normal balance" do
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2008-07-01" # set for supplemental days

    prev_period = Period.new(2018,1)
    # init balances
    set_previous_vacation_balances(employee, prev_period, 123233, 6.0)
    generate_work_hours(employee, prev_period)
    prev_payslip = Payslip.process(employee, prev_period)

    period_suppl_days = Vacation.period_supplemental_days(employee, prev_period)
    assert_equal(1/3.0, period_suppl_days, "should be normal value")

    assert_equal((1.5 + period_suppl_days).round(3), prev_payslip.vacation_earned.round(3), "correct days earned")
    assert_equal((7.5 + period_suppl_days).round(3), prev_payslip.vacation_balance.round(3))

    prev_balance = prev_payslip.vacation_balance

    period = Period.new(2018,2)
    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)

    assert_equal((1.5 + (1/3.0)).round(3), payslip.vacation_earned.round(3), "correct days earned")
    assert_equal((prev_balance + 1.5 + (1/3.0)).round(3), payslip.vacation_balance.round(3), "correct days in bal")
    # verify no error produced
    assert(payslip.errors.empty?, "yep, no errors")
  end

  test "Vacation Pay Calculation" do
    employee = return_valid_employee
    employee.contract_start = "2008-01-01" # set for supplemental days

    period = Period.new(2018,3)

    previous_pay_balance = 245345
    previous_balance = 33
    set_previous_vacation_balances(employee, period, previous_pay_balance, previous_balance)
    generate_work_hours(employee, period)

    # have a vacation that is over the reg days but under reg + suppl
    vacation = Vacation.create!(employee: employee, start_date: '2018-03-05', end_date: '2018-03-09')
    hours = {
      "2018-03-05" => {hours: 0.0},
      "2018-03-06" => {hours: 0.0},
      "2018-03-07" => {hours: 0.0},
      "2018-03-08" => {hours: 0.0},
      "2018-03-09" => {hours: 0.0},
    }
    # Still working the 28th
    WorkHour.update(employee, hours)
    assert_equal(5, vacation.days, "should be correct number of days")

    # have a vacation that is over the reg days but under reg + suppl
    payslip = Payslip.process(employee, period)

    assert_equal(249990, previous_pay_balance + payslip.calc_vacation_pay_earned,
        "cur_balance correct")

    vpu = ( payslip.vacation_daily_rate * vacation.days ).round
    # FIXME, this really needs to be fixed.
    assert_equal(vpu, payslip.vacation_pay_used, "Correctly Vacation Pay")
  end

  test "Payslip will error if not enough days to pay vacaion" do
    # process payslip
    # verify error is produced.
    employee = return_valid_employee()
    employee.uniondues = false;
    employee.amical = 0;
    employee.contract_start = "2008-07-01" # set for supplemental days

    prev_period = Period.new(2018,1)
    # init balances
    set_previous_vacation_balances(employee, prev_period, 123233, 6.0)
    generate_work_hours(employee, prev_period)
    prev_payslip = Payslip.process(employee, prev_period)

    period_suppl_days = Vacation.period_supplemental_days(employee, prev_period)
    assert_equal(4/12.0, period_suppl_days, "should be normal value")

    assert_equal((1.5 + period_suppl_days).round(3), prev_payslip.vacation_earned.round(3), "correct days earned")
    assert_equal((7.5 + 4/12.0).round(3), prev_payslip.vacation_balance.round(3))

    period = Period.new(2018,2)
    generate_work_hours(employee, period)

    # have a vacation that is over the reg days but under reg + suppl
    vacation = Vacation.create!(employee: employee, start_date: '2018-02-01', end_date: '2018-02-16')
    hours = {
      "2018-02-01" => {hours: 0.0},
      "2018-02-02" => {hours: 0.0},
      "2018-02-05" => {hours: 0.0},
      "2018-02-06" => {hours: 0.0},
      "2018-02-07" => {hours: 0.0},
      "2018-02-08" => {hours: 0.0},
      "2018-02-09" => {hours: 0.0},
      "2018-02-12" => {hours: 0.0},
      "2018-02-13" => {hours: 0.0},
      "2018-02-14" => {hours: 0.0},
      "2018-02-15" => {hours: 0.0},
      "2018-02-16" => {hours: 0.0}
    }
    # Still working the 28th
    WorkHour.update(employee, hours)

    assert_equal(12, vacation.days, "should be correct number of days")
    assert(vacation.days > prev_payslip.vacation_balance + 1.5 + (0.33 * 2)) # magic numbers

    # no output of stack trace during test run
    current_level = Rails.logger.level
    Rails.logger.level = :fatal

    # process payslip
    payslip = Payslip.process(employee, period)

    # verify error produced
    refute(payslip.errors.empty?, "yep, an error!")
    assert(payslip.errors.include?(:base), "yep, an error with vacation_balance")

    # reset logger level
    Rails.logger.level = current_level
  end

  # FIXME, adjust if necessary or remove.
  test "Rerun with supplemental days anniversary: same result" do
    employee = return_valid_employee()
    employee.first_day = "2010-02-01"
    employee.contract_start = "2010-02-01"

    period = Period.new(2018,2)
    generate_work_hours employee, period

    # process
    payslip = Payslip.process(employee, period)
    days_earned = payslip.vacation_earned

    # re-process
    payslip = Payslip.process(employee, period)
    days_earned_second_time = payslip.vacation_earned

    assert_equal(days_earned_second_time, days_earned, "reprocessing is the same")
  end

  test "Test payslip with vacation_worked." do
    employee = return_valid_employee
    employee.contract_start = "2008-01-01" # set for supplemental days

    period = Period.new(2018,3)

    previous_pay_balance = 245345
    previous_balance = 33
    set_previous_vacation_balances(employee, period, previous_pay_balance, previous_balance)
    generate_work_hours(employee, period)

    vac_hours_worked = 6.0
    vacation = Vacation.create!(
        employee: employee,
        start_date: '2018-03-05', end_date: '2018-03-11')
    hours = {
      "2018-03-05" => {hours: 0.0},
      "2018-03-06" => {hours: 0.0, vacation_worked: vac_hours_worked},
      "2018-03-07" => {hours: 0.0},
      "2018-03-08" => {hours: 0.0},
      "2018-03-09" => {hours: 0.0},
      "2018-03-10" => {hours: 0.0},
      "2018-03-11" => {hours: 0.0},
    }
    WorkHour.update(employee, hours)
    assert_equal(5, vacation.days, "should be correct number of days")

    exp = { normal: 136.0, vacation_worked: vac_hours_worked }
    assert_equal(exp, WorkHour.total_hours(employee, period))
    payslip = Payslip.process(employee, period)

    found = false
    payslip.earnings.each do |e|
      if (e.rate == employee.hourly_rate)
        found = true
        assert_equal(e.amount,(employee.hourly_rate * vac_hours_worked), "correct earning")
      end
    end

    assert(found, "Found earning for vacation worked")

    # Vacation weekday overtime
    vac_hours_worked = 9.0
    hours = {
      "2018-03-05" => {hours: 0.0},
      "2018-03-06" => {hours: 0.0, vacation_worked: vac_hours_worked},
      "2018-03-07" => {hours: 0.0},
      "2018-03-08" => {hours: 0.0},
      "2018-03-09" => {hours: 0.0},
      "2018-03-10" => {hours: 0.0},
      "2018-03-11" => {hours: 0.0},
    }
    WorkHour.update(employee, hours)
    assert_equal(5, vacation.days, "should be correct number of days")

    exp = { normal: 136.0, vacation_worked: 9 }
    assert_equal(exp, WorkHour.total_hours(employee, period))
    payslip = Payslip.process(employee, period)

    found = false
    payslip.earnings.each do |e|
      if (e.rate == employee.hourly_rate)
        found = true
        assert_equal(e.amount,(employee.hourly_rate * 9), "correct earning")
      end
    end
    assert(found, "Found earning for vacation worked")

    # Vacation Saturday Hours
    hours = {
      "2018-03-06" => {hours: 0.0, vacation_worked: 0},
      "2018-03-10" => {hours: 0.0, vacation_worked: vac_hours_worked},
    }
    WorkHour.update(employee, hours)

    exp = { normal: 136.0, vacation_worked: vac_hours_worked }
    assert_equal(exp, WorkHour.total_hours(employee, period))
    payslip = Payslip.process(employee, period)

    found = false
    payslip.earnings.each do |e|
      if (e.rate == employee.hourly_rate)
        found = true
        assert_equal(e.amount,(employee.hourly_rate * 9), "correct earning")
      end
    end
    assert(found, "Found earning for vacation worked")

    # Vacation Sunday(Holiday) Hours
    hours = {
      "2018-03-10" => {hours: 0.0, vacation_worked: 0},
      "2018-03-11" => {hours: 0.0, vacation_worked: vac_hours_worked},
    }
    WorkHour.update(employee, hours)

    exp = { normal: 136.0, vacation_worked: vac_hours_worked }
    assert_equal(exp, WorkHour.total_hours(employee, period))
    payslip = Payslip.process(employee, period)

    found = false
    payslip.earnings.each do |e|
      if (e.rate == employee.hourly_rate)
        found = true
        assert_equal(e.amount,(employee.hourly_rate * vac_hours_worked), "correct earning")
      end
    end
    assert(found, "Found earning for vacation worked")
  end

  test "Inactive people have their payslip disappear" do
    # Because they shouldn't be paid.

    employee = return_valid_employee()
    period = Period.new(2018,8)

    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)
    assert(payslip, "payslip exists")

    # Find via another means.
    payslip = employee.payslip_for(period)
    assert(payslip, "payslip exists")

    employee.employment_status = "inactive"

    payslip = Payslip.process(employee, period)
    refute(payslip, "payslip should now be nil for this period")

    # Find via another means.
    payslip = employee.payslip_for(period)
    refute(payslip, "payslip exists")

    assert_equal(0, employee.payslips.where("period_month = ? AND period_year = ?",
        period.month, period.year).count(), "should return 0 payslips")
  end

  test "Missing payslip can compute previous balances correctly" do
    # Example, someone that is inactive for multiple months,
    # The system should just pick up based on their prior
    # payslip (the last one they received) -- even through it
    # could be many months ago.
    employee = return_valid_employee()
    period = Period.new(2018,3)

    generate_work_hours(employee, period)

    # Create a payslip in march
    payslip = Payslip.process(employee, period)
    assert(payslip, "march payslip")
    mar_vac_balance = payslip.vacation_balance

    # Inactive from april -> july
    period = period.next # april
    employee.employment_status = "inactive"

    payslip = Payslip.process(employee, period)
    refute(payslip, "april payslip")

    period = period.next # may
    payslip = Payslip.process(employee, period)
    refute(payslip, "may payslip")

    period = period.next # june
    payslip = Payslip.process(employee, period)
    refute(payslip, "june payslip")

    period = period.next # july
    payslip = Payslip.process(employee, period)
    refute(payslip, "july payslip")

    # Create a payslip in august.
    period = period.next # august
    employee.employment_status = "full_time"
    payslip = Payslip.process(employee, period)
    assert(payslip, "august payslip")

    previous_payslip = payslip.previous
    assert(previous_payslip, "previous payslip can be found")
    assert_equal(3, previous_payslip.period_month, "correct month")
    assert_equal(2018, previous_payslip.period_year, "correct year")
    assert_equal(mar_vac_balance, previous_payslip.vacation_balance,
        "correct vac balance from march")

    assert_equal(
        payslip.vacation_balance,
        mar_vac_balance + payslip.vacation_earned,
          "Balance in August is correct")
  end

  test "Test bonuses applied once" do
    # have employee
    # have bonuses
    # payslip process
    # Do we get two??
    employee = return_valid_employee()
    period = Period.new(2018,10)
    generate_work_hours(employee, period)

    assert_equal(0, employee.bonuses.size, "no bonuses")

    bonus = Bonus.new
    bonus.name = "Test Bonus 1"
    bonus.bonus_type = "fixed"
    bonus.quantity = 25000
    employee.bonuses << bonus

    assert_equal(1, employee.bonuses.size, "no bonuses")

    payslip = Payslip.process(employee, period)
    assert_equal(1, payslip.earnings.where("is_bonus = ?", true).size)

    newbonus = Bonus.new
    newbonus.name = "Test Bonus 2"
    newbonus.bonus_type = "fixed"
    newbonus.quantity = 15000
    employee.bonuses << newbonus

    assert_equal(2, employee.bonuses.size, "no bonuses")

    payslip = Payslip.process(employee, period)
    assert_equal(2, payslip.earnings.where("is_bonus = ?", true).size)
  end

  test "Payslip Loan Balance isn't always current" do
    current_period = Period.current
    jan_18_period = Period.new(2018,1)

    assert(current_period > jan_18_period)

    employee = return_valid_employee
    generate_work_hours employee, jan_18_period

    cur_bal = Loan.total_balance(employee) # current period
    assert_equal(0, cur_bal, "jan 18 originally had no loan balance")

    jan_18_payslip = Payslip.process(employee, jan_18_period)
    assert(jan_18_payslip, "valid")
    assert_equal(0, jan_18_payslip.loan_balance, "no loan balance in jan 18")

    # create a new loan, verify it doesn't show up in the past
    loan_amount = 50000
    new_loan = employee.loans.create(origination: current_period.start, amount: loan_amount)
    assert(new_loan)

    cur_bal = Loan.total_balance(employee) # current period
    assert_equal(loan_amount, cur_bal, "yep, worked.")

    # process payslip from jan_18
    jan_18_payslip = Payslip.process(employee, jan_18_period)
    assert(jan_18_payslip, "valid")
    assert_equal(0, jan_18_payslip.loan_balance, "no loan balance in jan 18 after adding future loan")
  end

  test "base bonuses can use caisse base or not" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)
    assert employee.valid?

    # create bonuses
    bonus = Bonus.new
    bonus.name = "First Bonus"
    bonus.quantity = 0.12
    bonus.base_percentage!
    bonus.use_caisse = false
    assert bonus.valid?
    bonus.save

    # assign to employee
    employee.bonuses << bonus
    assert_equal(1, employee.bonuses.size)

    # give overtime work hours
    hours = {'2017-08-01' => {hours: 12},
             '2017-08-02' => {hours: 12},
             '2017-08-03' => {hours: 12},
             '2017-08-04' => {hours: 12}
    }

    WorkHour.update employee, hours

    ### verify hours
    exp = { normal: 184.0, overtime: 16.0 }
    assert_equal exp, WorkHour.total_hours(employee, Period.new(2017, 8))

    payslip = Payslip.process(employee, Period.new(2017,8))

    # Find specific earnings entries
    first = payslip.earnings.where(description: "First Bonus").take

    # just uses wage (OT doesn't matter)
    bonusbase = employee.wage
    assert_equal(( bonusbase * bonus.quantity ).floor, first.amount,
        "correct bonus for bonus")

    # Now include seniority bonus.
    bonus.use_caisse = true
    assert bonus.valid?
    bonus.save

    payslip = Payslip.process(employee, Period.new(2017,8))

    first = payslip.earnings.where(description: "First Bonus").take
    bonusbase = employee.wage + payslip.seniority_bonus
    assert_equal(( bonusbase * bonus.quantity ).floor, first.amount,
        "correct bonus for bonus")
  end

  test "Vacation whole month cause zero payslip" do
    employee = return_valid_employee()
    employee.transportation = 10000;
    employee.uniondues = true;
    assert employee.valid?

    period = Period.new(2018,5)

    holidays = Holiday.for_year(2018)
    holidays_in_2018 = holidays.count

    hl1 = Holiday.create!(name: "National Day", date: "2018-05-20", observed: "2018-05-21")
    hl2 = Holiday.create!(name: "Relaxing Day", date: "2018-05-30")
    hl3 = Holiday.create!(name: "Labor Day", date: "2018-05-01")
    # verify they really are holidays.
    assert_equal(holidays_in_2018 + 3, Holiday.for_year(2018).count)

    v = Vacation.create!(employee: employee,
        start_date: "2018-05-02", end_date: "2018-05-31")

    hours = {
      '2018-05-01' => {hours: 0},
    }
    success, errors = WorkHour.update employee, hours
    assert(success)

    payslip = Payslip.process(employee, period)
    assert(payslip)
    assert(payslip.on_vacation_entire_period?, "yes on vaca")

    assert_equal(3, WorkHour.days_worked(employee, period))
    assert_equal(0, payslip.days_worked, "payslip shouldn't have worked")

    # Zero payslip.
    assert_equal(0, payslip.net_pay)
    assert_equal(0, payslip.base_pay)
    assert_equal(0, payslip.caissebase)
    assert_equal(0, payslip.seniority_bonus_amount)
    assert_equal(0, payslip.cnpswage)
    assert_equal(0, payslip.union_dues, "union dues should be zero")
    assert_equal(0, payslip.transportation, "transportation hould be zero")
    assert_equal(0, payslip.taxable)
  end

  # FIXME, no accumulation into regular vacation earned
  test "Vacation Accrual during Zero Month should stop" do
    employee = return_valid_employee()
    employee.contract_start = "2009-10-01"
    employee.first_day = "2009-10-01"
    employee.save
    may_18 = Period.new(2018,5)

    # Last Month He Worked
    previous_period = may_18.previous
    generate_work_hours(employee, previous_period)
    previous_payslip = Payslip.process(employee, previous_period)
    assert(previous_payslip)

    period_suppl_days = Vacation.period_supplemental_days(employee, previous_period)
    prev_payslip_vac_balance = previous_payslip.vacation_balance
    prev_payslip_vac_pay_balance = previous_payslip.vacation_pay_balance

    assert(previous_payslip.net_pay > 1000, "net pay is something")
    assert_equal((1.5 + period_suppl_days).round(3), previous_payslip.vacation_earned.round(3), "should accrue during normal month")

    # This month he didn't work
    v = Vacation.create!(employee: employee,
        start_date: "2018-05-01", end_date: "2018-07-12")

    tot_vac_days = v.days
    assert_equal(tot_vac_days, v.days, "should be may,june, and some of july")
    assert_equal(Period.new(2018,5), v.apply_to_period, "should be may")
    assert_equal(23, v.days_in_period(may_18))

    payslip = Payslip.process(employee, may_18)
    assert(payslip)

    assert_equal(0, payslip.net_pay, "net pay is zero, since there was no work")
    assert_equal(0, payslip.period_suppl_days.round(3), "This is right amount")

    # NB.This is the raw data, the payslip decides whether to use any at all
    assert_equal(0.17, Vacation.period_supplemental_days(employee, may_18).round(2),
      "supplemental days is correct")
    days_earned_this_payslip = Vacation.days_earned(employee, may_18) # amount eligible to earn

    assert_equal(0, payslip.vacation_earned) # should be no earning in May

    assert_equal(v.days, payslip.vacation_used, "debited full vacation in May period")
    assert_equal(183049, payslip.vacation_pay_used, "should be vacation used in this month")

    # Vacation/Pay Balance Tests
    assert_equal(
        prev_payslip_vac_balance - payslip.vacation_used + payslip.vacation_earned,
        payslip.vacation_balance, "v_bal okay")

    may_balance = payslip.vacation_balance
    # now rate * avail days.
    assert_equal((payslip.vacation_daily_rate * payslip.vacation_balance).round,
        payslip.vacation_pay_balance, "v pay bal okay")

    # FIXME Pay earned should go away?
    # This will be zero due to supplemental transfer.
    assert_equal(0, payslip.vacation_pay_earned,
        "No pay earned since it was transferred and off the whole month")

    # FIXME what is this testing?
    assert_equal(0, payslip.vacation_earned, "only earned supplemental transfer days")
    assert_equal(0, payslip.vacation_earned.round(2), "should not accrue while on vacation?")

    # Vacation balances
    # What to do, test and verify
    assert(v.vacation_pay > 0, "vacation pay should be something")

    jun = may_18.next
    jun_payslip = Payslip.process(employee, jun)
    assert(jun_payslip)

    # FIXME: remove
   # refute(Vacation.transfer_supplemental_days?(employee, jun), "no transfer")
    assert(jun_payslip.on_vacation_entire_period?)
    assert_equal(0, jun_payslip.period_suppl_days) # no suppl earning
    assert_equal(0, jun_payslip.vacation_earned) # no earning at all

    assert_equal(0, jun_payslip.net_pay, "still no pay in #{jun}")

    jul = jun.next

    # 2018-07-12 to end of month.
    hours = {'2018-07-13' => {hours: 12},
             '2018-07-16' => {hours: 12},
             '2018-07-17' => {hours: 12},
             '2018-07-18' => {hours: 12},
             '2018-07-19' => {hours: 12},
             '2018-07-20' => {hours: 12},
             '2018-07-23' => {hours: 12},
             '2018-07-24' => {hours: 12},
             '2018-07-25' => {hours: 12},
             '2018-07-26' => {hours: 12},
             '2018-07-27' => {hours: 12},
             '2018-07-30' => {hours: 12},
             '2018-07-31' => {hours: 12}
    }
    success, errors = WorkHour.update(employee, hours)
    assert(success)

    jul_payslip = Payslip.process(employee, jul)
    assert(jul_payslip)
    refute(jul_payslip.on_vacation_entire_period?)

    assert_equal(77310, jul_payslip.net_pay, "should receive pay in #{jul}")
    assert_equal(0.167, jul_payslip.period_suppl_days.round(3), "This is right amount")

    # should earn again, plus period suppl days
    assert_equal((1.5 + jul_payslip.period_suppl_days).round(3), jul_payslip.vacation_earned.round(3))

    assert_equal(
        (may_balance + 0 + # No earning in Jun
          (1.5 + jul_payslip.period_suppl_days)).round(2), # Normal earning in July
        jul_payslip.vacation_balance.round(2), "balances are good")
  end

  test "Full Gross Wage is correct when on vacation whole month" do
    period = Period.new(2019,5)
    employee = return_valid_employee()
    employee.category = "seven"
    employee.echelon = "c"
    employee.uniondues = true;
    employee.amical = 3000;
    employee.uniondues = true;
    employee.transportation = 20000;
    employee.first_day = "2009-10-01";
    employee.contract_start = "2009-10-01";
    employee.save
    assert employee.valid?

    assert_equal(143550, employee.wage)

    # Bonuses
    employee.bonuses.push(bonuses :primeex)
    employee.bonuses.push(bonuses :primedr20k)
    employee.bonuses.push(bonuses :logementpercent)

    assert_equal(3, employee.bonuses.size, "should have 3 bonuses")

    holidays = Holiday.for_year(2018)
    holidays_in_2018 = holidays.count

    hl1 = Holiday.create!(name: "National Day", date: "2018-05-20", observed: "2018-05-21")
    hl2 = Holiday.create!(name: "Relaxing Day", date: "2018-05-30")
    hl3 = Holiday.create!(name: "Labor Day", date: "2018-05-01")
    # verify they really are holidays.
    assert_equal(holidays_in_2018 + 3, Holiday.for_year(2018).count)

    v = Vacation.create!(employee: employee,
        start_date: "2018-05-02", end_date: "2018-05-31")

    hours = {
      '2018-05-01' => {hours: 0},
    }
    success, errors = WorkHour.update employee, hours
    assert(success)

    payslip = Payslip.process(employee, period)
    assert(payslip)

    assert_equal(143550, payslip.full_base_pay)
    assert_equal(22310, payslip.seniority_bonus(true))
    assert_equal(270390, payslip.compute_fullcnpswage)
  end

  test "New Employee's First Payslip" do
    employee = return_valid_employee()
    employee.contract_start = "2018-05-07"
    employee.first_day = "2018-05-07"
    employee.save

    period = Period.new(2018,5)
    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)
    assert(payslip)

    assert_equal(1.5, payslip.vacation_earned)
    assert_equal(payslip.taxable.fdiv(16).ceil, payslip.vacation_pay_earned)
    assert_equal(0, payslip.period_suppl_days)
  end

  test "Pay Correction works" do
    employee = return_valid_employee()
    employee.contract_start = "2018-05-07"
    employee.first_day = "2018-05-07"
    employee.accrue_vacation = true;
    employee.save

    period = Period.new(2022,1)

    # ensure we have a perious payslip to work with.
    prev_vac_pay_bal = 75665
    prev_vac_bal = 19.5
    set_previous_vacation_balances(employee, period, prev_vac_pay_bal, prev_vac_bal)

    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period);
    prev_payslip = payslip.previous
    net_pay = payslip.net_pay

    # need to use 5 franc increments.
    positive_correction = 9570
    negative_correction = -3140

    # Add a payslip correction (cfa credit, positive).
    assert_equal(0, employee.payslip_corrections.size);
    psc = PayslipCorrection.new
    psc.payslip = prev_payslip
    psc.cfa = positive_correction
    psc.note = "Error fix"
    # If not overriden, PSC will use LastPostedPeriod.current as the current period
    psc.applied_year = period.year
    psc.applied_month = period.month
    psc.save
    assert_equal(0, psc.errors.size, psc.errors.inspect)
    prev_payslip.payslip_corrections << psc

    assert_equal(1, employee.payslip_corrections.for_period(period).size)
    assert_equal(period.month, psc.applied_month)
    assert_equal(period.year, psc.applied_year)

    payslip = Payslip.process(employee, period);
    assert_equal(net_pay + positive_correction, payslip.net_pay,
        "payslip is increased by correection") 

    # Add a second payslip correction, (cfa credit, negative)
    psc = PayslipCorrection.new
    psc.payslip = prev_payslip
    psc.cfa = negative_correction
    psc.applied_year = period.year
    psc.applied_month = period.month
    prev_payslip.payslip_corrections << psc
    assert_equal(2, employee.payslip_corrections.for_period(period).size)
    
    payslip = Payslip.process(employee, period);
    assert_equal(net_pay + positive_correction + negative_correction,
        payslip.net_pay, "payslip is increased by corrrection") 

    # Next Payslip is not increased
    generate_work_hours(employee, period.next)
    next_payslip = Payslip.process(employee, period.next)
    assert_equal(net_pay, next_payslip.net_pay, 
        "next payslip is not increased")
  end

  test "Vaction Correction works" do
    employee = return_valid_employee()
    employee.contract_start = "2018-05-07"
    employee.first_day = "2018-05-07"
    employee.accrue_vacation = true;
    employee.save

    period = Period.new(2022,1)

    prev_vac_pay_bal = 75665
    prev_vac_bal = 19.5
    set_previous_vacation_balances(employee, period, prev_vac_pay_bal, prev_vac_bal)

    payslip = Payslip.process(employee, period);

    prev_payslip = payslip.previous;
    assert_equal(19.5, prev_payslip.vacation_balance);

    # Vacation for 20 days
    #     January 2022
    # Su Mo Tu We Th Fr Sa
    #                    1
    #  2  3  4  5  6  7  8
    #  9 10 11 12 13 14 15
    # 16 17 18 19 20 21 22
    # 23 24 25 26 27 28 29
    # 30 31
    vac = Vacation.new(start_date: "2022-01-03", end_date: "2022-01-28")
    employee.vacations << vac

    # no output of stack trace during test run
    current_level = Rails.logger.level
    Rails.logger.level = :fatal

    # Reprocess, and Verify it fails.
    payslip = Payslip.process(employee, period) # Should fail!
    # veriy failure of processing.
    assert_equal(1, payslip.errors.size, "should have 1 error indicating a problem with this payslip")

    # reset logger level
    Rails.logger.level = current_level

    # Add a payslip correction.
    assert(0, employee.payslip_corrections.for_period(period).size);
    psc = PayslipCorrection.new
    psc.applied_year = period.year
    psc.applied_month = period.month
    psc.payslip = payslip.previous
    psc.vacation_days = 1
    psc.save
    prev_payslip.payslip_corrections << psc
    assert(1, employee.payslip_corrections.for_period(period).size);

    # verify it works.
    # Reprocess, and Verify it works
    payslip = Payslip.process(employee, period) # Should work
    # verify failure of processing.
    assert_equal(0, payslip.errors.size, "should have 0 error indicating a problem with this payslip")
  end

  test "Multiple Vaction Correction works" do
    employee = return_valid_employee()
    employee.contract_start = "2018-05-07"
    employee.first_day = "2018-05-07"
    employee.accrue_vacation = true;
    employee.save

    period = Period.new(2022,1)

    prev_vac_pay_bal = 75665
    prev_vac_bal = 19.5
    generate_work_hours(employee, period.previous)
    set_previous_vacation_balances(employee, period, prev_vac_pay_bal, prev_vac_bal)

    prev_payslip = Payslip.for_employee_for_period(employee, period.previous)
    assert_equal(prev_vac_bal, prev_payslip.vacation_balance)

    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)
    assert_equal(prev_vac_bal + 1.5, payslip.vacation_balance) # 1.5 should be added from prev.

    assert_equal(1.5, Vacation.days_earned(employee, period))
    assert_equal(1.5, payslip.vacation_earned())

    # Add a payslip correction.
    assert_equal(0, employee.payslip_corrections.for_period(period).size);
    psc1 = PayslipCorrection.new
    psc1.payslip = prev_payslip
    psc1.applied_year = period.year
    psc1.applied_month = period.month
    psc1.vacation_days = 1
    psc1.save
    prev_payslip.payslip_corrections << psc1
    assert_equal(1, employee.payslip_corrections.for_period(period).size)

    # Add a second payslip correction.
    assert_equal(1, employee.payslip_corrections.for_period(period).size)
    psc2 = PayslipCorrection.new
    psc2.payslip = prev_payslip
    psc2.applied_year = period.year
    psc2.applied_month = period.month
    psc2.vacation_days = 2
    psc2.save
    prev_payslip.payslip_corrections << psc2
    assert_equal(2, employee.payslip_corrections.for_period(period).size)

    # verify it works.
    # Reprocess, and Verify it works
    payslip = Payslip.process(employee, period) # Should work
    # veriy failure of processing.
    assert_equal(0, payslip.errors.size, "should have 0 error indicating a problem with this payslip")

    assert_equal(1.5, Vacation.days_earned(employee, period))
    assert_equal(1.5, payslip.vacation_earned())

    # 19.5 + 1.5 + 3 (1+2) = 24?
    assert_equal(prev_vac_bal + 1.5 + 1 + 2, payslip.vacation_balance)
    #Rails.logger.level = current_level

    # Next period doesn't get more than usual
    generate_work_hours(employee, period.next)
    next_payslip = Payslip.process(employee, period.next);

    assert_equal(0, next_payslip.errors.size, "should have 0 error indicating a problem with this payslip")
    assert_equal(prev_vac_bal + 1.5 + 1 + 2 + 1.5, next_payslip.vacation_balance)
  end

  test "Leave Produces a Payslip which is 0" do
    dec19 = Period.new(2019,12)
    employee = return_valid_employee()
    generate_work_hours(employee, dec19)

    payslip = Payslip.process(employee, dec19)
    assert(payslip, "should receive payslip in dec19")
    assert(payslip.salaire_net > 0, "should be paid in dec19")

    employee.employment_status = "leave"
    employee.save

    payslip = Payslip.process(employee, dec19)
    assert(payslip, "should receive payslip in dec19")
    assert(payslip.salaire_net == 0, "should be paid in dec19")
  end

  test "Feb 20 leap year" do
    employee = return_valid_employee()

    period = Period.new(2020,2)
    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)
    assert(payslip)
    assert(payslip.worked_full_month?)

    found_monthly = false
    payslip.earnings.each do |e|
      found_monthly = true if e.description == "Monthly Wages"
    end
    assert(found_monthly)
  end

  # These don't exist anymore
  test "Supplemental Transfers" do
    employee = return_valid_employee()

    assert_raise NoMethodError do
      employee.last_supplemental_transfer
    end

    assert_raise NameError do
      SupplementalTransfer.new
    end
  end

  test "bonuses can be post tax (percentage based)" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)
    assert employee.valid?

    # Add bonus (post tax)
    # Check total
    # Verify tax doesn't change
    # Verify gross doesn't change
    # Verify net does change by non-taxed amount

    # create pre bonus
    # (existence of pre bonus should not be problematic)
    pre_bonus = Bonus.new
    pre_bonus.name = "Pre Tax Percentage Bonus"
    pre_bonus.quantity = 0.10
    pre_bonus.percentage!
    pre_bonus.post_tax = false
    assert pre_bonus.valid?
    pre_bonus.save
    employee.bonuses << pre_bonus
    assert_equal(1, employee.bonuses.size)

    # Figure out employee tax, gross, and net
    payslip = Payslip.process(employee, Period.new(2017,8))

    orig_payslip_tax_amount = payslip.total_tax
    orig_payslip_gross_amount = payslip.gross_pay
    orig_payslip_net_amount  = payslip.net_pay

    # create post bonus
    post_bonus = Bonus.new
    post_bonus.name = "Post Tax Percentage Bonus"
    post_bonus.quantity = 0.052
    post_bonus.percentage!
    post_bonus.post_tax = true
    assert post_bonus.valid?
    post_bonus.save

    # assign to employee
    employee.bonuses << post_bonus
    assert_equal(2, employee.bonuses.size)

    payslip = Payslip.process(employee, Period.new(2017,8))

    first = payslip.deductions.where(note: "Post Tax Percentage Bonus").take
    base = payslip.gross_pay

    # Verify amount of bonus
    # This will effetively be a negative amount, or an adjustment
    #   to the salary
    assert_equal(( -1 * orig_payslip_gross_amount * post_bonus.quantity ).round,
                first.amount, "correct amount for bonus")


    # Verify tax doesn't change
    assert_equal orig_payslip_tax_amount, payslip.total_tax
    # Verify gross doesn't change
    assert_equal orig_payslip_gross_amount, payslip.gross_pay
    # Verify net does change by non-taxed amount
    new_payslip_net_amount = payslip.net_pay # increased by 5.2%
    new_payslip_gross_amount = payslip.gross_pay # not increased

    # Verify pay has been incrased by the specified amount.
    pay_diff = new_payslip_net_amount - orig_payslip_net_amount
    assert_equal(0.052, pay_diff.fdiv(orig_payslip_gross_amount).round(3))
  end

  test "bonuses can be post tax (fixed amount)" do
    employee = return_valid_employee()
    generate_work_hours employee, Period.new(2017, 8)
    assert employee.valid?

    # Add bonus (post tax)
    # Check total
    # Verify tax doesn't change
    # Verify gross doesn't change
    # Verify net does change by non-taxed amount

    # create pre bonus
    # (existence of pre bonus should not be problematic)
    pre_bonus = Bonus.new
    pre_bonus.name = "Pre Tax Percentage Bonus"
    pre_bonus.quantity = 0.10
    pre_bonus.percentage!
    pre_bonus.post_tax = false
    assert pre_bonus.valid?
    pre_bonus.save
    employee.bonuses << pre_bonus
    assert_equal(1, employee.bonuses.size)

    # Figure out employee tax, gross, and net
    payslip = Payslip.process(employee, Period.new(2017,8))

    orig_payslip_tax_amount = payslip.total_tax
    orig_payslip_gross_amount = payslip.gross_pay
    orig_payslip_net_amount  = payslip.net_pay

    # create post bonus
    post_bonus = Bonus.new
    post_bonus.name = "Post Tax Fixed Bonus"
    post_bonus.quantity = 10000
    post_bonus.fixed!
    post_bonus.post_tax = true
    assert post_bonus.valid?
    post_bonus.save

    # assign to employee
    employee.bonuses << post_bonus
    assert_equal(2, employee.bonuses.size)

    payslip = Payslip.process(employee, Period.new(2017,8))

    first = payslip.deductions.where(note: "Post Tax Fixed Bonus").take
    base = payslip.gross_pay

    # Verify amount of bonus
    assert_equal(-10000, first.amount, "correct amount for bonus")

    # Verify tax doesn't change
    assert_equal orig_payslip_tax_amount, payslip.total_tax
    # Verify gross doesn't change
    assert_equal orig_payslip_gross_amount, payslip.gross_pay
    # Verify net does change by non-taxed amount
    new_payslip_net_amount = payslip.net_pay
    new_payslip_gross_amount = payslip.gross_pay # not increased
    assert_equal(new_payslip_gross_amount, orig_payslip_gross_amount)

    # Verify pay has been incrased by the specified amount.
    pay_diff = new_payslip_net_amount - orig_payslip_net_amount
    assert_equal(10000, pay_diff)
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
