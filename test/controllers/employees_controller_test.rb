require "test_helper"

class EmployeesControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  test "Things a User CANNOT do"  do
    login_user(:Luke)
    refute_user_permission(new_employee_url(), "get") # new
    refute_user_permission(employees_url(), "post", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }) # create
    refute_user_permission(employee_url(employees(:Han)), "get") # get other
    refute_user_permission(edit_employee_url(employees(:Han)), "get") # edit other
    refute_user_permission(edit_employee_url(employees(:Luke)), "get") # edit self
    refute_user_permission("/employees/#{employees(:Han).id}", "patch", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }) # update other
    refute_user_permission("/employees/#{employees(:Luke).id}", "patch", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }) # update self
    refute_user_permission("/employees/#{employees(:Han).id}", "delete") # delete other
    refute_user_permission("/employees/#{employees(:Luke).id}", "delete") # delete self
  end

  # Things a user CAN do
  test "USER: GET employee#index" do
    login_user(:Luke)
    get employees_url

    assert_response :success
    assert_select "tbody#employees-data tr td a" do |element|
      assert_equal("Skywalker, Luke", element.children.first.content, "should only be able to see self")
      assert_equal(1, element.children.size, "should only be able to see self")
    end
  end

  # Navigation tests
  test "USER: new employee button is missing on INDEX" do
    login_user(:Luke)
    get employees_url
    assert_response :success
    assert_select "#new-employee-btn", false
  end

  test "USER: edit and delete employee buttons are missing on show SELF" do
    login_user(:Luke)
    get employee_url(employees(:Luke))
    assert_response :success

    # add/delete buttons
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :personal), false
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :basic_employee), false
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :wage), false
    assert_select "a[href=?]", new_employee_raise_path(employees(:Luke)), false
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :misc), false
    assert_select "#delete-employee-btn", false

    # various administration links
    # TO be done when other controllers have policy/authorize checks
    #  assert_select "#add-child-link", false
    #  assert_select "#add-vacation-link", false
    #  assert_select "#add-charge-link", false
    #  assert_select "#add-hours-link", false
    #  assert_select "#add-loan-link", false
    #  assert_select "#assign-bonuses-link", false
  end

  # SUPERVISOR
  test "This a supervisor CANNOT do"  do
    login_supervisor(:Quigon)

    refute_supervisor_permission(new_employee_url(), "get") # new
    refute_supervisor_permission(employees_url(), "post", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }) # create
    refute_supervisor_permission(employee_url(employees(:Han)), "get") # get other
    refute_supervisor_permission(edit_employee_url(employees(:Han)), "get") # edit other
    refute_supervisor_permission("/employees/#{employees(:Han).id}", "patch", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }) # update other
    refute_supervisor_permission("/employees/#{employees(:Quigon).id}", "patch", params: { employee: { supervisor_id: employees(:Quigon).supervisor.id, title: "Test Employee", first_name: "Test", last_name: "Employee" }}) #edit self
    refute_supervisor_permission("/employees/#{employees(:Han).id}", "delete") # delete other
    refute_supervisor_permission("/employees/#{employees(:Luke).id}", "delete") # delete self
    refute_supervisor_permission("/employees/#{employees(:Obiwan).id}", "delete") # delete report
  end

  test "SUPERVISOR: GET employee#show for SELF" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Quigon))

    assert_response :success
    assert_select "h2", "Employee Information for #{employees(:Quigon).full_name}"
  end

  test "SUPERVISOR: GET employee#show for direct report" do
    login_supervisor(:Quigon)

    verify_is_supervisor(:Quigon, :Obiwan)
    get employee_url(employees(:Obiwan))

    assert_response :success
    assert_select "h2", "Employee Information for #{employees(:Obiwan).full_name}"
  end

  # should see direct reports
  test "SUPERVISOR: GET employee#index" do
    login_supervisor(:Quigon)
    get employees_url(view_all: true)

    assert_response :success
    assert_select "tbody#employees-data tr td a" do |element|
      assert_equal("Kenobi, Obiwan", element.children.last.content, "should be able to see report")
      assert_equal(2, element.children.size, "should be able to see report and self")
    end

    assert_select "#new-employee-btn", false
  end

  # should see direct reports' direct reports
#  test "SUPERVISOR: GET employee#index MULTILEVEL" do
#    luke = users :Luke
#    sign_in_as(luke)
#
#    get employees_url
#
#    assert_response :success
#
#    assert(false, "finish this test, rewrite it")
#
#    assert_select "tbody#employees-data tr td a" do |element|
#      assert_equal("Luke Skywalker", element.children.first.content, "should only be able to see self")
#      assert_equal(2, element.children.size, "should only be able to see self")
#    end
#  end


  test "SUPERVISOR: view edit page for direct report" do
    login_supervisor(:Quigon)

    verify_is_supervisor(:Quigon, :Obiwan)
    get edit_employee_url(employees(:Obiwan), page: :personal)

    assert_response :success
    assert_select "input#employee_first_name[value=#{employees(:Obiwan).first_name}]"
  end


  test "SUPERVISOR: UPDATE direct report" do
    login_supervisor(:Quigon)

    verify_is_supervisor(:Quigon, :Obiwan)
    patch "/employees/#{employees(:Obiwan).id}", params: { employee: { supervisor_id: employees(:Obiwan).supervisor.id, title: "Test Employee", first_name: "Test", last_name: "Employee" }}

    assert_response :redirect
    assert_select "p#permissions-error", false
  end


  test "SUPERVISOR: edit and delete employee buttons on employee#show REPORT" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Obiwan))

    assert_response :success

    # add/dete buttons
    assert_select "a[href=?]", edit_employee_path(employees(:Obiwan), page: :personal), true
    assert_select "a[href=?]", edit_employee_path(employees(:Obiwan), page: :basic_employee), true
    assert_select "a[href=?]", edit_employee_path(employees(:Obiwan), page: :wage), true
    assert_select "a[href=?]", new_employee_raise_path(employees(:Obiwan)), true
    assert_select "a[href=?]", edit_employee_path(employees(:Obiwan), page: :misc), true
    assert_select "#delete-employee-btn", false

    # various administration links
    #assert_select "#add-child-link", false
    #assert_select "#add-vacation-link", false
    #assert_select "#add-charge-link", false
    #assert_select "#add-hours-link", false
    #assert_select "#add-loan-link", false
    #assert_select "#assign-bonuses-link", false
  end

  # REPEAT FOR admin

  test "ADMIN: GET employee#new" do
    login_admin(:MaceWindu)
    get new_employee_url

    assert_response :success
    assert_select "input#employee_first_name"
  end

  test "ADMIN: POST employee#create" do
    login_admin(:MaceWindu)
    post "/employees", params: { page: "personal", employee: { first_name: "Test", last_name: "Employee" }}

    assert_response :success
    assert_select "input#employee_title" # Should be on page 2 of the new employee form
  end

  test "ADMIN: GET employee#show" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Han))

    assert_response :success
    assert_select "h2", "Employee Information for #{employees(:Han).full_name}"
  end

  # should see all
  test "ADMIN: GET employee#index" do
    login_admin(:MaceWindu)
    get employees_url(view_all: true)

    assert_response :success
    assert_select "tbody#employees-data tr td a" do |element|
      no_employees = Employee.all.size
      assert_equal(no_employees, element.children.size, "should only be able to see report")
    end

    assert_select "#new-employee-btn"
  end

  test "ADMIN: view edit page" do
    login_admin(:MaceWindu)
    get edit_employee_url(employees(:Han), page: :personal)

    assert_response :success
    assert_select "input#employee_first_name[value=#{employees(:Han).first_name}]"
  end

  test "ADMIN: UPDATE employee" do
    login_admin(:MaceWindu)
    patch "/employees/#{employees(:Obiwan).id}", params: { employee: { supervisor_id: employees(:Obiwan).supervisor.id, title: "Test Employee", first_name: "Test", last_name: "Employee" }}

    assert_response :redirect
    assert_select "p#permissions-error", false
  end

  test "ADMIN: can DELETE employee" do
    login_admin(:MaceWindu)
    delete "/employees/#{employees(:Han).id}"

    assert_response :redirect
    assert_select "p#permissions-error", false
  end

  test "ADMIN: all edit and delete employee buttons show on employee#show" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Luke))

    assert_response :success

    # add/dete buttons
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :personal), true
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :basic_employee), true
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :wage), true
    assert_select "a[href=?]", new_employee_raise_path(employees(:Luke)), true
    assert_select "a[href=?]", edit_employee_path(employees(:Luke), page: :misc), true
    assert_select "#delete-employee-btn", true

    # various administration links
    assert_select "#add-vacation-link"
    assert_select "#add-charge-link"
    assert_select "#add-hours-link"
    assert_select "#add-loan-link"
  end
end
