require "test_helper"

class WorkLoansControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  test "Work Loans: User"  do
    login_user(:Luke)
    luke_emp = employees(:Luke)

    refute_user_permission(work_loans_url(), "get") # index
    refute_user_permission(work_loans_url(), "post", params: {
        work_loan: { employee_id: luke_emp.id, date: '2017-08-01',
            hours: '2', department_person: 'Rick Conrad' }}) # create
    refute_user_permission(new_work_loan_url(), "get") # new
    refute_user_permission(work_loan_url(work_loans(:LoanOne)), "delete") # destroy
  end

  test "USER: can't see link on home#home" do
    login_user(:Luke)
    get root_url()

    assert_select "a#work-loans-link", false
  end

  test "Work Loans: Supervisor"  do
    login_supervisor(:Quigon)
    luke_emp = employees(:Luke)

    refute_supervisor_permission(work_loans_url(), "get") # index
    refute_supervisor_permission(work_loans_url(), "post", params: {
        work_loan: { employee_id: luke_emp.id, date: '2017-08-01',
            hours: '2', department_person: 'Rick Conrad' }}) # create
    refute_supervisor_permission(new_work_loan_url(), "get") # new
    refute_supervisor_permission(work_loan_url(work_loans(:LoanOne)), "delete") # destroy
  end

  test "Supervisor: can't see link on home#home" do
    login_supervisor(:Quigon)
    get root_url()

    assert_select "a#work-loans-link", false
  end

  test "Work Loans: Admin"  do
    login_admin(:MaceWindu)
    luke_emp = employees(:Luke)

    assert_supervisor_permission(work_loans_url(), "get") # index
    assert_supervisor_permission(work_loans_url(), "post", params: {
        work_loan: { employee_id: luke_emp.id, date: '2017-08-01',
            hours: '2', department_person: 'Rick Conrad' }}) # create
    assert_supervisor_permission(new_work_loan_url(), "get") # new
    assert_supervisor_permission(work_loan_url(work_loans(:LoanOne)), "delete") # destroy
  end

  test "Admin: can see link on home#home" do
    login_admin(:MaceWindu)
    get root_url()

    assert_select "a#work-loans-link"
  end
end
