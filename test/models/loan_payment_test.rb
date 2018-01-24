require "test_helper"

class LoanPaymentTest < ActiveSupport::TestCase

  def setup
    @luke = employees :Luke
    @loan_one = loans :one
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test LoanPayment, some_valid_params
  end

  test "Get all payments for period" do
    anakin = employees :Anakin

    # pay off this loan in july
    julyloan = loans :twokjuly

    julypay = LoanPayment.new
    julypay.amount = 2000
    julypay.date = "2017-07-02"
    julyloan.loan_payments << julypay

    # this loan's payments should appear in the call
    augloan = loans :sixkaug

    augpay = LoanPayment.new
    augpay.amount = 3000
    augpay.date = "2017-08-02"
    augloan.loan_payments << augpay

    # get August payments
    augpayments = LoanPayment.get_all_payments(anakin, Period.new(2017,8))
    assert_equal(1, augpayments.size())
  end

  test "can't add or edit during posted period" do
    # Can't add loan during posted pay period
    pay = LoanPayment.new
    pay.amount = 8
    pay.date = '2017-07-30'
    pay.loan = loans :julloan

    refute pay.valid?, "should not be able to create during posted period"

    # Can't add loan during posted pay period
    pay = LoanPayment.new
    pay.amount = 10
    pay.date = '2017-08-03'
    pay.loan = loans :augloan

    assert pay.valid?, "should be valid outside of posted period"
  end

  test "can't delete during posted period" do
    LastPostedPeriod.post_current
    augpay = loan_payments :augpay

    augpay.destroy
    assert_includes LoanPayment.all(), augpay
  end

  test "can delete during posted period" do
    septpay = loan_payments :septpay

    septpay.destroy
    refute_includes LoanPayment.all(), septpay
  end

  test "loan payment can be cash" do
    septpay = loan_payments :septpay

    septpay.cash_payment = true
    assert(septpay.cash?, "should be a cash payment")

    septpay.cash_payment = false
    refute(septpay.cash?, "should now not be a cash payment")
  end

  def some_valid_params
    { loan: @loan_one, date: '2017-10-02', amount: 90 }
  end

end
