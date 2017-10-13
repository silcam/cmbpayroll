require "test_helper"

class EmployeesControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  test "USER: GET employee#new" do
    luke = users :Luke
    assert(luke.user?, "luke is user")

    sign_in_as(luke)

    get new_employee_url

    assert_permissions_error
  end

  test "USER: POST employee#create" do
    luke = users :Luke
    sign_in_as(luke)

    post "/employees", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }

    assert_permissions_error
  end

  test "USER: GET employee#show" do
    luke = users :Luke
    sign_in_as(luke)

    get employee_url(employees(:Han))

    assert_permissions_error
  end

  test "USER: GET employee#index" do
    luke = users :Luke
    sign_in_as(luke)

    get employees_url

    assert_response :success

    assert_select "tbody#employees-data tr td a" do |element|
      assert_equal("Luke Skywalker", element.children.first.content, "should only be able to see self")
      assert_equal(2, element.children.size, "should only be able to see self")
    end
  end

  test "USER: view edit page OTHER" do
    luke = users :Luke
    sign_in_as(luke)

    han = employees(:Han)
    get edit_employee_url(han)

    assert_permissions_error
  end

  test "USER: view edit page SELF" do
    luke = users :Luke
    sign_in_as(luke)

    get edit_employee_url(employees(:Luke))

    assert_permissions_error
  end

  test "USER: UPDATE other employee" do
    luke = users :Luke
    sign_in_as(luke)

    han = employees(:Han)
    patch "/employees/#{han.id}", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }

    assert_permissions_error
  end

  test "USER: UPDATE self" do
    luke = users :Luke
    sign_in_as(luke)

    patch "/employees/#{luke.id}", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }

    assert_permissions_error
  end

  test "USER: DELETE employee" do
    luke = users :Luke
    sign_in_as(luke)

    han = employees(:Han)
    delete "/employees/#{han.id}"

    assert_permissions_error
  end

  test "USER: DELETE self" do
    luke = users :Luke
    sign_in_as(luke)

    delete "/employees/#{luke.id}"

    assert_permissions_error
  end

  test "USER: new employee button is missing on INDEX" do
    luke = users :Luke
    sign_in_as(luke)

    get employees_url

    assert_response :success
    assert_select "#new-employee-btn", false
  end

  test "USER: edit and delete employee buttons are missing on show SELF" do
    luke = users :Luke
    sign_in_as(luke)

    get employee_url(employees(:Luke))

    assert_response :success

    # add/dete buttons
    assert_select "#edit-employee-btn", false
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

  # REPEAT FOR supervisor

  test "SUPERVISOR: GET employee#new" do
    quigon = users :Quigon
    assert(quigon.supervisor?, "quigon is supervisor")

    sign_in_as(quigon)

    get new_employee_url

    assert_permissions_error
  end

  test "SUPERVISOR: POST employee#create" do
    quigon = users :Quigon
    sign_in_as(quigon)

    post "/employees", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }

    assert_permissions_error
  end

  test "SUPERVISOR: GET employee#show NON report" do
    quigon = users :Quigon
    sign_in_as(quigon)

    get employee_url(employees(:Han))

    assert_permissions_error
  end

  test "SUPERVISOR: GET employee#show for SELF" do
    quigon = users :Quigon
    sign_in_as(quigon)

    quigon_emp = employees(:Quigon)

    get employee_url(quigon)

    assert_response :success
    assert_select "h2", "Employee Information for #{quigon.full_name}"
  end

  test "SUPERVISOR: GET employee#show for direct report" do
    quigon = users :Quigon
    sign_in_as(quigon)

    obiwan = employees(:Obiwan)
    assert_equal(quigon.person, obiwan.supervisor.person, "verify relationship")

    get employee_url(obiwan)

    assert_response :success
    assert_select "h2", "Employee Information for #{obiwan.full_name}"
  end

  # should see direct reports
  test "SUPERVISOR: GET employee#index" do
    quigon = users :Quigon
    sign_in_as(quigon)

    get employees_url

    assert_response :success

    assert_select "tbody#employees-data tr td a" do |element|
      assert_equal("Obiwan Kenobi", element.children.first.content, "should only be able to see report")
      assert_equal(2, element.children.size, "should only be able to see report")
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

  test "SUPERVISOR: view edit page OTHER" do
    quigon = users :Quigon
    sign_in_as(quigon)

    han = employees(:Han)
    get edit_employee_url(han)

    assert_permissions_error
  end

  test "SUPERVISOR: view edit page for direct report" do
    quigon = users :Quigon
    sign_in_as(quigon)

    obiwan = employees(:Obiwan)

    assert_equal(quigon.person, obiwan.supervisor.person, "verify relationship")

    get edit_employee_url(obiwan)

    assert_response :success
    assert_select "input#employee_first_name[value=#{obiwan.first_name}]"
    assert_select "#new-employee-btn", false, "new employee button on edit page should not appear"
  end

  test "SUPERVISOR: UPDATE other employee" do
    quigon = users :Quigon
    sign_in_as(quigon)

    han = employees(:Han)
    patch "/employees/#{han.id}", params: { title: "Test Employee", first_name: "Test", last_name: "Employee" }

    assert_permissions_error
  end

  test "SUPERVISOR: UPDATE direct report" do
    quigon = users :Quigon
    sign_in_as(quigon)

    obiwan = employees(:Obiwan)
    assert_equal(quigon.person, obiwan.supervisor.person, "verify relationship")

    patch "/employees/#{obiwan.id}", params: { employee: { supervisor_id: obiwan.supervisor.id, title: "Test Employee", first_name: "Test", last_name: "Employee" }}

    assert_response :redirect
    assert_select "p#permissions-error", false
  end

  test "SUPERVISOR: UPDATE self" do
    quigon = users :Quigon
    sign_in_as(quigon)

    quigon_emp = employees :Quigon
    patch "/employees/#{quigon_emp.id}", params: { employee: { supervisor_id: quigon_emp.supervisor.id, title: "Test Employee", first_name: "Test", last_name: "Employee" }}

    assert_permissions_error
  end

  test "SUPERVISOR: cannot DELETE employee" do
    quigon = users :Quigon
    sign_in_as(quigon)

    han = employees(:Han)
    delete "/employees/#{han.id}"

    assert_permissions_error
  end

  test "SUPERVISOR: cannot DELETE self" do
    quigon = users :Quigon
    sign_in_as(quigon)

    delete "/employees/#{quigon.id}"

    assert_permissions_error
  end

  test "SUPERVISOR: cannot DELETE report" do
    quigon = users :Quigon
    sign_in_as(quigon)

    obiwan = employees(:Obiwan)
    delete "/employees/#{obiwan.id}"

    assert_permissions_error
  end


  test "SUPERVISOR: edit and delete employee buttons are missing on employee#show REPORT" do
    quigon = users :Quigon
    sign_in_as(quigon)

    obiwan = employees(:Obiwan)
    get employee_url(obiwan)

    assert_response :success

    # add/dete buttons
    assert_select "#edit-employee-btn"
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
    mace = users :MaceWindu
    assert(mace.admin?, "mace is admin")

    sign_in_as(mace)

    get new_employee_url

    assert_response :success
    assert_select "input#employee_first_name"
  end

  test "ADMIN: POST employee#create" do
    mace = users :MaceWindu
    sign_in_as(mace)

    yoda = people :Yoda
    post "/employees", params: { employee: { supervisor_id: yoda.id, title: "Test Employee", first_name: "Test", last_name: "Employee" }}

    assert_response :success
    assert_select "input#employee_first_name"
  end

  test "ADMIN: GET employee#show" do
    mace = users :MaceWindu
    sign_in_as(mace)

    han = employees(:Han)
    get employee_url(han)

    assert_response :success
    assert_select "h2", "Employee Information for #{han.full_name}"
  end

  # should see all
  test "ADMIN: GET employee#index" do
    mace = users :MaceWindu
    sign_in_as(mace)

    get employees_url

    assert_response :success

    no_employees = Employee.all.size

    assert_select "tbody#employees-data tr td a" do |element|
      # time 2 because 2 links per record.
      assert_equal(no_employees * 2, element.children.size, "should only be able to see report")
    end

    assert_select "#new-employee-btn"
  end

  test "ADMIN: view edit page" do
    mace = users :MaceWindu
    sign_in_as(mace)

    han = employees(:Han)
    get edit_employee_url(han)

    assert_response :success
    assert_select "input#employee_first_name[value=#{han.first_name}]"
  end

  test "ADMIN: UPDATE employee" do
    mace = users :MaceWindu
    sign_in_as(mace)

    obiwan = employees(:Obiwan)

    patch "/employees/#{obiwan.id}", params: { employee: { supervisor_id: obiwan.supervisor.id, title: "Test Employee", first_name: "Test", last_name: "Employee" }}

    assert_response :redirect
    assert_select "p#permissions-error", false
  end

  test "ADMIN: can DELETE employee" do
    mace = users :MaceWindu
    sign_in_as(mace)

    han = employees(:Han)
    delete "/employees/#{han.id}"

    assert_response :redirect
    assert_select "p#permissions-error", false
  end

  test "ADMIN: all edit and delete employee buttons show on employee#show" do
    mace = users :MaceWindu
    sign_in_as(mace)

    get employee_url(employees(:Luke))

    assert_response :success

    # add/dete buttons
    assert_select "#edit-employee-btn"
    assert_select "#delete-employee-btn"

    # various administration links
    assert_select "#add-child-link"
    assert_select "#add-vacation-link"
    assert_select "#add-charge-link"
    assert_select "#add-hours-link"
    assert_select "#add-loan-link"
    assert_select "#assign-bonuses-link"
  end
end
