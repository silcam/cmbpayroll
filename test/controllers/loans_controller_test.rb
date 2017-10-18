require "test_helper"

class LoansControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### USER ####
  test "Things a User CANNOT do" do
    login_user(:Luke)

    assert_user_permission(employee_loans_url(employees(:Luke)), "get") # index
    refute_user_permission(employee_loans_url(employees(:Luke)), "post", params: {
        loan: { amount: 15000, comment: 'Desc', origination: DateTime.now, term: "six_month_term" }}) # create
    refute_user_permission(new_employee_loan_url(employees(:Luke)), "get") # new
    refute_user_permission(edit_loan_url(Loan.all.first), "get") # edit
    refute_user_permission(loan_url(Loan.all.first), "patch", params: { loan: { commment: 'New Desc' }}) # update
    refute_user_permission(loan_url(Loan.all.first), "delete") # delete
  end

  test "USER: can't see add loan link on employee#show" do
    login_user(:Luke)
    get employee_url(employees(:Luke))

    assert_select "a#add-loan-link", false
  end

  test "USER: can't see links on loans#index" do
    login_user(:Luke)

    luke = employees(:Luke)
    loan = luke.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(luke.loans.size > 0, "Luke has loans")

    get employee_loans_url(luke)

    assert_select "a#new-loan-btn", false

    assert_select "a.edit-loan-link", false
    assert_select "a.delete-loan-link", false

    # make it a paid loan
    loan.loan_payments.create!(amount: loan.amount, date: DateTime.now)
    assert(loan.is_paid, "loan should be paid now")
    assert(Loan.paid_loans(luke).size > 0, "has paid loans")

    get employee_loans_url(luke)
    assert_response :success

    assert_select "a.edit-paid-loan-link", false
    assert_select "a.delete-paid-loan-link", false
  end

  #### Supervisor ####
  test "Things a Supervisor CANNOT do" do
    login_supervisor(:Quigon)

    ben_loan = employees(:Obiwan).loans.create!(amount: 15000, comment: 'asd', origination: DateTime.now, term: "six_month_term")

    assert_supervisor_permission(employee_loans_url(employees(:Obiwan)), "get") # index
    refute_supervisor_permission(employee_loans_url(employees(:Obiwan)), "post", params: {
        loan: { amount: 15000, comment: 'Desc', origination: DateTime.now, term: "six_month_term" }}) # create
    refute_supervisor_permission(new_employee_loan_url(employees(:Obiwan)), "get") # new
    refute_supervisor_permission(edit_loan_url(ben_loan), "get") # edit
    refute_supervisor_permission(loan_url(ben_loan), "patch", params: { loan: { commment: 'New Desc' }}) # update
    refute_supervisor_permission(loan_url(ben_loan), "delete") # delete
  end

  test "Supervisor: can't see add loan link on employee#show" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Obiwan))

    assert_select "a#add-loan-link", false
  end

  test "Supervisor: can't see loan links on loans#index" do
    login_supervisor(:Quigon)

    obiwan = employees(:Obiwan)
    loan = obiwan.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(obiwan.loans.size > 0, "Ben has loans")

    get employee_loans_url(obiwan)

    assert_select "a#new-loan-btn", false

    assert_select "a.edit-loan-link", false
    assert_select "a.delete-loan-link", false

    # make it a paid loan
    loan.loan_payments.create!(amount: loan.amount, date: DateTime.now)
    assert(loan.is_paid, "loan should be paid now")
    assert(Loan.paid_loans(obiwan).size > 0, "has paid loans")

    get employee_loans_url(obiwan)
    assert_response :success

    assert_select "a.edit-paid-loan-link", false
    assert_select "a.delete-paid-loan-link", false
  end

  #### Admin ####
  test "Things an Admin CANNOT do" do
    login_admin(:MaceWindu)

    ben_loan = employees(:Obiwan).loans.create!(amount: 15000, comment: 'asd', origination: DateTime.now, term: "six_month_term")

    assert_admin_permission(employee_loans_url(employees(:Obiwan)), "get") # index
    assert_admin_permission(employee_loans_url(employees(:Obiwan)), "post", params: {
        loan: { amount: 15000, comment: 'Desc', origination: DateTime.now, term: "six_month_term" }}) # create
    assert_admin_permission(new_employee_loan_url(employees(:Obiwan)), "get") # new
    assert_admin_permission(edit_loan_url(ben_loan), "get") # edit
    assert_admin_permission(loan_url(ben_loan), "patch", params: { loan: { commment: 'New Desc' }}) # update
    assert_admin_permission(loan_url(ben_loan), "delete") # delete
  end

  test "Admin: can see add loan link on employee#show" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Han))

    assert_select "a#add-loan-link"
  end

  test "Admin: can see loan links on loans#index" do
    login_admin(:MaceWindu)

    han = employees(:Han)
    loan = han.loans.create!(amount: 15000, origination: DateTime.now, term: "six_month_term")
    assert(han.loans.size > 0, "Han has loans")

    get employee_loans_url(han)

    assert_select "a#new-loan-btn"

    assert_select "a.edit-loan-link"
    assert_select "a.delete-loan-link"

    # make it a paid loan
    loan.loan_payments.create!(amount: loan.amount, date: DateTime.now)
    assert(loan.is_paid, "loan should be paid now")
    assert(Loan.paid_loans(han).size > 0, "has paid loans")

    get employee_loans_url(han)
    assert_response :success

    assert_select "a.edit-paid-loan-link"
    assert_select "a.delete-paid-loan-link"
  end
end
