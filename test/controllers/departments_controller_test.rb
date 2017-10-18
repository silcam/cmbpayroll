require "test_helper"

class DepartmentsControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### USER ####

  test "Things a User CANNOT do" do
    login_user(:Luke)

    refute_user_permission(departments_url(), "get") # index
    refute_user_permission(departments_url(), "post", params: { department: { name: 'Test Dept', description: 'Desc', account: '1234' }}) # create
    refute_user_permission(new_department_url(), "get") # new
    refute_user_permission(edit_department_url(Department.all.first), "get") # edit
    refute_user_permission(department_url(Department.all.first), "get") # show
    refute_user_permission(department_url(Department.all.first), "patch", params: { department: { account: '2345' }}) # update
    refute_user_permission(department_url(Department.all.first), "delete") # delete
  end


  #### Supervisor ####

  test "Things a Supervisor CANNOT do" do
    login_supervisor(:Quigon)

    refute_user_permission(departments_url(), "get") # index
    refute_user_permission(departments_url(), "post", params: { department: { name: 'Test Dept', description: 'Desc', account: '1234' }}) # create
    refute_user_permission(new_department_url(), "get") # new
    refute_user_permission(edit_department_url(Department.all.first), "get") # edit
    refute_user_permission(department_url(Department.all.first), "get") # show
    refute_user_permission(department_url(Department.all.first), "patch", params: { department: { account: '2345' }}) # update
    refute_user_permission(department_url(Department.all.first), "delete") # delete
  end

  #### ADMIN ####

  test "Things an Admin can do" do
    login_admin(:MaceWindu)

    assert_user_permission(departments_url(), "get") # index
    assert_user_permission(departments_url(), "post", params: { department: { name: 'Test Dept', description: 'Desc', account: '1234' }}) # create
    assert_user_permission(new_department_url(), "get") # new
    assert_user_permission(edit_department_url(Department.all.first), "get") # edit
    assert_user_permission(department_url(Department.all.first), "get") # show
    assert_user_permission(department_url(Department.all.first), "patch", params: { department: { account: '2345' }}) # update

    newdept = Department.create!(name: 'New Dept', description: 'Desc', account: '2345')
    assert_user_permission(department_url(newdept), "delete") # delete
  end

end
