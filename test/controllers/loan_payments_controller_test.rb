require "test_helper"

class LoanPaymentsControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  def setup
    @luke = employees(:Luke)
    @luke_loan = @luke.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(@luke.loans.size > 0, "Luke has loans")
    @luke_pmnt = @luke_loan.loan_payments.create!(amount: @luke_loan.amount, date: DateTime.now)

    @obiwan = employees(:Obiwan)
    @obiwan_loan = @obiwan.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(@obiwan.loans.size > 0, "Luke has loans")
    @obiwan_pmnt = @obiwan_loan.loan_payments.create!(amount: @obiwan_loan.amount, date: DateTime.now)

    @han = employees(:Han)
    @han_loan = @han.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(@han.loans.size > 0, "Luke has loans")
    @han_pmnt = @han_loan.loan_payments.create!(amount: @han_loan.amount, date: DateTime.now)
  end

  #### USER ####

  test "Loan Payments : User" do
    login_user(:Luke)

    refute_user_permission(loan_loan_payments_url(@luke_loan), "post", params: { loan_payment: { amount: 15000, date: DateTime.now }}) # create
    refute_user_permission(new_loan_loan_payment_url(@luke_loan), "get") # new
    refute_user_permission(edit_loan_payment_url(@luke_pmnt), "get") # edit
    refute_user_permission(loan_payment_url(@luke_pmnt), "patch", params: { loan_payment: { amount: 14999 }}) # update
    refute_user_permission(loan_payment_url(@luke_pmnt), "delete") # delete
  end

  test "USER: can't see links on loans#index" do
    login_user(:Luke)

    new_loan = @luke.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(@luke.loans.size > 0, "Luke has loans")
    new_pmnt = new_loan.loan_payments.create!(amount: 7, date: DateTime.now)
    assert(new_loan.loan_payments.size > 0, "loan has payments")

    get employee_loans_url(@luke)

    assert_select "a.add-loanpayment-link", false
    assert_select "a.edit-loanpayment-link", false
    assert_select "a.delete-loanpayment-link", false
  end

  #### Supervisor ####

  test "Loan Payments: Supervisor" do
    login_supervisor(:Quigon)

    refute_supervisor_permission(loan_loan_payments_url(@obiwan_loan), "post", params: { loan_payment: { amount: 15000, date: DateTime.now }}) # create
    refute_supervisor_permission(new_loan_loan_payment_url(@obiwan_loan), "get") # new
    refute_supervisor_permission(edit_loan_payment_url(@obiwan_pmnt), "get") # edit
    refute_supervisor_permission(loan_payment_url(@obiwan_pmnt), "patch", params: { loan_payment: { amount: 14999 }}) # update
    refute_supervisor_permission(loan_payment_url(@obiwan_pmnt), "delete") # delete
  end

  test "Supervisor: can't see links on loans#index" do
    login_supervisor(:Quigon)

    new_loan = @obiwan.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(@obiwan.loans.size > 0, "Luke has loans")
    new_pmnt = new_loan.loan_payments.create!(amount: 7, date: DateTime.now)
    assert(new_loan.loan_payments.size > 0, "loan has payments")

    get employee_loans_url(@obiwan)

    assert_select "a.add-loanpayment-link", false
    assert_select "a.edit-loanpayment-link", false
    assert_select "a.delete-loanpayment-link", false
  end

  #### Admin ####

  test "Loan Payments : ADMIN" do
    login_admin(:MaceWindu)

    assert_admin_permission(loan_loan_payments_url(@han_loan), "post", params: { loan_payment: { amount: 15000, date: DateTime.now }}) # create
    assert_admin_permission(new_loan_loan_payment_url(@han_loan), "get") # new
    assert_admin_permission(edit_loan_payment_url(@han_pmnt), "get") # edit
    assert_admin_permission(loan_payment_url(@han_pmnt), "patch", params: { loan_payment: { amount: 14999 }}) # update
    assert_admin_permission(loan_payment_url(@han_pmnt), "delete") # delete
  end

  test "Admin: can see links on loans#index" do
    login_admin(:MaceWindu)

    new_loan = @han.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(@han.loans.size > 0, "Luke has loans")
    new_pmnt = new_loan.loan_payments.create!(amount: 7, date: DateTime.now)
    assert(new_loan.loan_payments.size > 0, "loan has payments")

    get employee_loans_url(@han)

    assert_select "a.add-loanpayment-link.btn.btn-primary"
    assert_select "a.edit-loanpayment-link"
    assert_select "a.delete-loanpayment-link"
  end
end
