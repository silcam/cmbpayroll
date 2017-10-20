require "test_helper"

class SupervisorsControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  test "Supervisors: User"  do
    login_user(:Luke)

    yoda = supervisors(:Yoda)
    refute_user_permission(employees_url(supervisor: yoda.id), "get") # employee index by supervisor

    refute_user_permission(supervisors_url(), "get") # index
    refute_user_permission(supervisors_url(), "post", params: { 
        supervisor: { first_name: 'first', last_name: 'last' }}) # create
    refute_user_permission(new_supervisor_url(), "get") # new
    refute_user_permission(supervisor_url(yoda), "delete") # delete
  end

  test "Supervisors: Supervisors"  do
    login_supervisor(:Quigon)

    yoda = supervisors(:Yoda)
    refute_supervisor_permission(employees_url(supervisor: yoda.id), "get") # employee index by supervisor

    refute_supervisor_permission(supervisors_url(), "get") # index
    refute_supervisor_permission(supervisors_url(), "post", params: { 
        supervisor: { first_name: 'first', last_name: 'last' }}) # create
    refute_supervisor_permission(new_supervisor_url(), "get") # new
    refute_supervisor_permission(supervisor_url(yoda), "delete") # delete
  end

  test "Supervisors: Admin"  do
    login_admin(:MaceWindu)

    yoda = supervisors(:Yoda)
    assert_admin_permission(employees_url(supervisor: yoda.id), "get") # employee index by supervisor

    assert_admin_permission(supervisors_url(), "get") # index
    assert_admin_permission(supervisors_url(), "post", params: { 
        supervisor: { first_name: 'first', last_name: 'last' }}) # create
    assert_admin_permission(new_supervisor_url(), "get") # new
    assert_admin_permission(supervisor_url(supervisors(:BB8)), "delete") # delete
  end

end
