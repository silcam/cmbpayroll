require "test_helper"

class LoanPaymentTest < ActiveSupport::TestCase

  def setup
    @luke = employees :Luke
    @loan_one = loans :one
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test LoanPayment, some_valid_params
  end

  test "can't add or edit during posted period" do
    Date.stub :today, Date.new(2017, 7, 30) do
      # Can't add loan during posted pay period
      pay = LoanPayment.new
      pay.amount = 8
      pay.loan = loans :julloan

      refute pay.valid?, "should not be able to create during posted period"
    end

    Date.stub :today, Date.new(2017, 8, 30) do
      # Can't add loan during posted pay period
      pay = LoanPayment.new
      pay.amount = 10
      pay.loan = loans :augloan

      assert pay.valid?, "should be valid outside of posted period"
    end
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

  def some_valid_params
    { loan: @loan_one, amount: 90 }
  end

end
