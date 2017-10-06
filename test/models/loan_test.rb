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
    loan.six_month_term!

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
    loan.six_month_term!

    assert_equal(1000, Loan.total_amount(employee))

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan
    loan.eight_month_term!

    assert_equal(2000, Loan.total_amount(employee))
  end

  test "Loan Totals Decrease with Payments" do
    employee = return_valid_employee()

    loan = Loan.new

    loan.origination = Date.today
    loan.comment = "Test Comment"
    loan.amount = 1000
    employee.loans << loan
    loan.six_month_term!

    assert_equal(1000, Loan.total_amount(employee))

    payment = LoanPayment.new
    payment.amount = 500
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
    loan1.six_month_term!

    assert_equal(1000, Loan.total_amount(employee))

    loan2 = Loan.new
    loan2.origination = Date.today
    loan2.comment = "Test Comment"
    loan2.amount = 2000
    employee.loans << loan2
    loan2.six_month_term!

    assert_equal(3000, Loan.total_amount(employee))

    payment1 = LoanPayment.new
    payment1.amount = 333
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
    loan.six_month_term!

    assert_equal(1000, Loan.total_amount(employee))

    payment = LoanPayment.new
    payment.amount = 500
    loan.loan_payments << payment

    assert_equal(500, loan.balance())

    payment = LoanPayment.new
    payment.amount = 5
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
    loan.six_month_term!

    assert_equal(1000, Loan.total_amount(employee))

    assert_raise(ActiveRecord::RecordInvalid) do
      loan.loan_payments.create!(amount: 1500)
    end

    assert_nothing_raised do
      loan.loan_payments.create!(amount: 6)
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
    loan.six_month_term!

    assert_equal(1000, Loan.total_amount(employee))

    assert_equal(1, Loan.unpaid_loans(employee).size)
    assert_equal(0, Loan.paid_loans(employee).size)

    loan.loan_payments.create!(amount: 1000)

    assert(loan.is_paid)
    assert_equal(0, Loan.total_amount(employee))

    assert_equal(0, Loan.unpaid_loans(employee).size)
    assert_equal(1, Loan.paid_loans(employee).size)

  end

  test "can't add during posted period" do
    on_sep_5 do
      # Can't add loan during posted pay period
      loan = Loan.new
      loan.amount = 2000
      loan.employee = @luke
      loan.origination = "2017-07-22"
      loan.term = "six_month_term"

      refute loan.valid?, "should not be valid if created during posted period"
      loan.origination = '2017-08-01'
      assert loan.valid?, "should be valid outside of posted period"
    end

  end

  test "can't edit during posted period" do
    assert(false)
  end

  test "can't delete during posted period" do
    assert(false)
  end

  def some_valid_params
    {employee: @luke, origination: '2017-08-09', term: :six_month_term, amount: 90000}
  end

end
