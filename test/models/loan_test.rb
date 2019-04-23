require "test_helper"

class LoanTest < ActiveSupport::TestCase

  def setup
    @luke = employees :Luke
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test Loan, some_valid_params
  end

  test "Amount numeric validation" do
    loan = Loan.new

    loan.employee = @luke
    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000

    assert(loan.valid?, "should be valid")

    loan.amount = -1000

    refute(loan.valid?, "negative values are not valid")

    loan.amount = 0.000002

    refute(loan.valid?, "must be at least 1")
  end

  test "Can Total Loans" do
    employee = return_valid_employee()

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan

    assert_equal(1000, Loan.total_amount(employee))

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan

    assert_equal(2000, Loan.total_amount(employee))
  end

  test "Loan Totals Decrease with Payments" do
    employee = return_valid_employee()

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan

    assert_equal(1000, Loan.total_amount(employee))

    payment = LoanPayment.new
    payment.amount = 500
    payment.date = Date.today
    loan.loan_payments << payment

    loan.save
    payment.save

    assert_equal(1000, Loan.total_amount(employee))
    assert_equal(500, Loan.total_balance(employee))
  end

  test "can compute outstanding balance for all loans" do
    employee = return_valid_employee()

    loan1 = Loan.new
    loan1.origination = Date.today
    loan1.comment = "Test Comment"
    loan1.amount = 1000
    employee.loans << loan1

    assert_equal(1000, Loan.total_amount(employee))

    loan2 = Loan.new
    loan2.origination = Date.today
    loan2.comment = "Test Comment"
    loan2.amount = 2000
    employee.loans << loan2

    assert_equal(3000, Loan.total_amount(employee))

    payment1 = LoanPayment.new
    payment1.amount = 333
    payment1.date = Date.today
    loan1.loan_payments << payment1

    assert_equal(3000, Loan.total_amount(employee))
    assert_equal(3000 - 333, Loan.total_balance(employee))
  end

  test "can compute outstanding balance per loan" do
    employee = return_valid_employee()

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan

    assert_equal(1000, Loan.total_amount(employee))

    payment = LoanPayment.new
    payment.amount = 500
    payment.date = Date.today
    loan.loan_payments << payment

    assert_equal(500, loan.balance())

    payment = LoanPayment.new
    payment.amount = 5
    payment.date = Date.today
    loan.loan_payments << payment

    assert_equal(495, loan.balance())
  end

  test "cannot over pay loan" do
    employee = return_valid_employee()

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan

    assert_equal(1000, Loan.total_amount(employee))

    assert_raise(ActiveRecord::RecordInvalid) do
      loan.loan_payments.create!(amount: 1500, date: Date.today)
    end

    assert_nothing_raised do
      loan.loan_payments.create!(amount: 6, date: Date.today)
    end
  end

  test "loan knows when it is paid and is not included in total emount" do
    employee = return_valid_employee()

    assert_equal(0, Loan.unpaid_loans(employee).size)
    assert_equal(0, Loan.paid_loans(employee).size)

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan

    assert_equal(1000, Loan.total_amount(employee))

    assert_equal(1, Loan.unpaid_loans(employee).size)
    assert_equal(0, Loan.paid_loans(employee).size)

    loan.loan_payments.create!(amount: 1000, date: Date.today)

    assert(loan.is_paid)
    assert_equal(0, Loan.total_amount(employee))

    assert_equal(0, Loan.unpaid_loans(employee).size)
    assert_equal(1, Loan.paid_loans(employee).size)
  end

  test "new_loan_amount_this_period" do
    employee = return_valid_employee()

    assert_equal(0, Loan.unpaid_loans(employee).size)
    assert_equal(0, Loan.paid_loans(employee).size)

    loanamount = 199333

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = loanamount
    loan.origination = "2017-10-22"
    employee.loans << loan
    assert(loan.valid?)
    assert(employee.valid?)
    assert(loan.save)
    assert(employee.save)

    sept17 = Period.new(2017,9)
    oct17 = Period.new(2017,10)
    nov17 = Period.new(2017,11)

    assert_equal(0, Loan.new_loan_amount_this_period(employee, sept17))
    assert_equal(loanamount, Loan.new_loan_amount_this_period(employee, oct17))
    assert_equal(0, Loan.new_loan_amount_this_period(employee, nov17))

    loan.origination = "2017-09-01"
    loan.save

    assert_equal(loanamount, Loan.new_loan_amount_this_period(employee, sept17))
    assert_equal(0, Loan.new_loan_amount_this_period(employee, oct17))
    assert_equal(0, Loan.new_loan_amount_this_period(employee, nov17))

    loan.origination = "2017-11-30"
    loan.save

    assert_equal(0, Loan.new_loan_amount_this_period(employee, sept17))
    assert_equal(0, Loan.new_loan_amount_this_period(employee, oct17))
    assert_equal(loanamount, Loan.new_loan_amount_this_period(employee, nov17))
  end

  test "Test Total Balance over time" do
    sept17 = Period.new(2017,9)
    oct17 = Period.new(2017,10)
    nov17 = Period.new(2017,11)
    dec17 = Period.new(2017,12)

    employee = return_valid_employee()

    assert_equal(0, Loan.unpaid_loans(employee).size)
    assert_equal(0, Loan.paid_loans(employee).size)
    assert_equal(0, employee.loans.count, "has no loans")

    loanamount = 100000

    loan = employee.loans.create!(origination: oct17.mid_month,
        comment: "October Loan", amount: loanamount)
    assert_equal(1, employee.loans.count, "has one loan now")
    assert_equal(0, employee.loans.first.loan_payments.count, "has no payments")
    assert(loan.valid?)

    assert_equal(loanamount, Loan.total_balance(employee),
        "new loan added to loan balance")
    assert_equal(0, Loan.total_balance(employee, sept17),
        "sept loan balance not increased by loan in oct")
    assert_equal(loanamount, Loan.total_balance(employee, oct17),
        "oct balance has oct loan")
    assert_equal(loanamount, Loan.total_balance(employee, nov17),
        "nov balance has oct loan")

    paymentamount = 50000
    pmnt = loan.loan_payments.create!(amount: paymentamount, date: nov17.mid_month)
    assert_equal(1, loan.loan_payments.count, "has one payment")
    refute(loan.is_paid, "loan is not yet paid")

    assert_equal(0, Loan.total_balance(employee, sept17))
    assert_equal(loanamount, Loan.total_balance(employee, oct17))
    assert_equal(loanamount - paymentamount, Loan.total_balance(employee, nov17))
    assert_equal(loanamount - paymentamount, Loan.total_balance(employee))

    # second 50k payment will pay off loan
    decpmnt = loan.loan_payments.create!(amount: paymentamount, date: dec17.mid_month)
    assert(decpmnt)
    assert(loan.is_paid, "loan is paid now in dec")

    assert_equal(0, Loan.total_balance(employee, sept17))
    assert_equal(loanamount, Loan.total_balance(employee, oct17))
    assert_equal(loanamount - paymentamount, Loan.total_balance(employee, nov17))
    assert_equal(loanamount - paymentamount - paymentamount, Loan.total_balance(employee, dec17))
  end

  test "can't add or edit during posted period" do
    on_sep_5 do
      # Can't add loan during posted pay period
      loan = Loan.new
      loan.amount = 2000
      loan.employee = @luke
      loan.origination = "2017-07-22"

      refute loan.valid?, "should not be valid if created during posted period"
      loan.origination = '2017-08-01'
      assert loan.valid?, "should be valid outside of posted period"
    end
  end

  test "can't delete during posted period" do
    LastPostedPeriod.post_current
    augloan = loans :augloan

    augloan.destroy
    assert_includes Loan.all(), augloan
  end

  test "can delete during posted period" do
    septloan = loans :septloan

    septloan.destroy
    refute_includes Loan.all(), septloan
  end

  def some_valid_params
    {employee: @luke, origination: '2017-08-09', amount: 90000}
  end

end
