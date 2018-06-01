require "test_helper"

class PayslipsControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  def setup
    @luke = employees(:Luke)
    @han = employees(:Han)
    @obiwan = employees(:Obiwan)
  end

  #### USER ####

  test "Payslips Pages : User" do
    login_user(:Luke)

    luke_payslip = create_and_return_payslip(@luke)
    han_payslip = create_and_return_payslip(@han)

    assert_user_permission(employee_payslips_url(@luke), "get") # payslip index
    refute_user_permission(employee_payslips_url(@han), "get") # payslip index

    assert_user_permission(payslip_url(luke_payslip), "get") # show payslip (self)
    refute_user_permission(payslip_url(han_payslip), "get") # show payslip (other)

    refute_user_permission(payslips_url(), "get") # payslip admin page
    refute_user_permission(payslip_process_employee_url(), "post", params: {
        employee: { id: @luke.id }}) # payslip processing page
    refute_user_permission(payslip_process_employee_complete_url(), "post", params: {
        employee: { id: @luke.id }, period: { year: 2017, month: 10 }}) # payslip processing confirm
    refute_user_permission(payslip_process_all_url(), "post", params: { commit: "Submit" }) # process all
    refute_user_permission(payslip_post_period_url(), "post", params: { commit: "Submit" }) # post period
    refute_user_permission(payslip_unpost_period_url(), "post", params: { commit: "Submit" }) # unpost period
  end

  test "User cannot see reprocess button on employee page" do
    login_user(:Luke)

    get employee_payslips_url(@luke)
    assert_select "input#employee-reprocess", false
  end

  test "Payslips Pages : Supervisor" do
    login_supervisor(:Quigon)

    obiwan_payslip = create_and_return_payslip(@obiwan)
    han_payslip = create_and_return_payslip(@han)

    assert_supervisor_permission(employee_payslips_url(@obiwan), "get") # payslip index
    refute_supervisor_permission(employee_payslips_url(@han), "get") # payslip index

    assert_supervisor_permission(payslip_url(obiwan_payslip), "get") # show payslip (report)
    refute_supervisor_permission(payslip_url(han_payslip), "get") # show payslip (other)

    refute_supervisor_permission(payslips_url(), "get") # payslip admin page
    refute_supervisor_permission(payslip_process_employee_url(), "post", params: {
        employee: { id: @luke.id }}) # payslip processing page
    refute_supervisor_permission(payslip_process_employee_complete_url(), "post", params: {
        employee: { id: @luke.id }, period: { year: 2017, month: 10 }}) # payslip processing confirm
    refute_supervisor_permission(payslip_process_all_url(), "post", params: { commit: "Submit" }) # process all
    refute_supervisor_permission(payslip_post_period_url(), "post", params: { commit: "Submit" }) # post period
    refute_supervisor_permission(payslip_unpost_period_url(), "post", params: { commit: "Submit" }) # unpost period
  end

  test "Payslips Pages : Admin" do
    login_admin(:MaceWindu)

    han_payslip = create_and_return_payslip(@han)

    assert_admin_permission(employee_payslips_url(@han), "get") # payslip index
    assert_admin_permission(payslip_url(han_payslip), "get") # show payslip (other)
    assert_admin_permission(payslips_url(), "get") # payslip admin page
    assert_admin_permission(payslip_process_employee_url(), "post", params: {
        employee: { id: @luke.id }}) # payslip processing page
    assert_admin_permission(payslip_process_employee_complete_url(), "post", params: {
        employee: { id: @luke.id }, period: { year: 2017, month: 10 }}) # payslip processing confirm
    assert_admin_permission(payslip_process_all_url(), "post", params: { commit: "Submit" }) # process all
    assert_admin_permission(payslip_post_period_url(), "post", params: { commit: "Submit" }) # post period
    assert_admin_permission(payslip_unpost_period_url(), "post", params: { commit: "Submit" }) # unpost period
  end

  test "Admin can see reprocess button on employee page" do
    login_admin(:MaceWindu)

    get employee_payslips_url(@luke)
    assert_select "#employee-reprocess"
  end

end
