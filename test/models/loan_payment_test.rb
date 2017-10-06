require "test_helper"

class LoanPaymentTest < ActiveSupport::TestCase

  def setup
    @luke = employees :Luke
    @loan_one = loans :one
  end

  test "Validate Presence of Required Attributes" do
    model_validation_hack_test LoanPayment, some_valid_params
  end

  def some_valid_params
    { loan: @loan_one, amount: 90 }
  end

end
