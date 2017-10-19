require "test_helper"

class ChildrenControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### USER ####

  test "Children : USER"  do
    login_user(:Luke)

    luke_emp = employees(:Luke)
    han = employees(:Han)
    lukejr = children(:LukeJr)
    kyloren = children(:Kylo)

    assert_user_permission(employee_children_url(luke_emp), "get") # index (self)
    refute_user_permission(employee_children_url(han), "get") # index (other)
    refute_user_permission(employee_children_url(luke_emp), "post", params: { child: {
        first_name: 'Little', last_name: 'Skywalker', birth_date: '2017-01-02',
            is_student: 'false' }})  # create
    refute_user_permission(new_employee_child_url(luke_emp), "get") # new
    refute_user_permission(edit_child_url(lukejr), "get") # edit
    refute_user_permission(child_url(lukejr), "patch", params: { child: { first_name: 'Lukey' }}) # update
    refute_user_permission(child_url(lukejr), "delete") # destroy
  end

  test "USER: can't see add child links on employee#show" do
    login(:Luke, "user")
    get employee_url(employees(:Luke))

    assert_select "a#add-child-link", false
  end

  test "USER: can't see links on child#index" do
    login_user(:Luke)
    get employee_children_url(employees(:Luke))

    assert_select "a#add-child-link", false
    assert_select "a#edit-child-link", false
    assert_select "a#delete-child-link", false
  end

  #### Supervisor ####

  test "Children : Supervisor"  do
    login_supervisor(:Quigon)

    obiwan = employees(:Obiwan)
    lilobi = children(:LilObi)

    assert_supervisor_permission(employee_children_url(obiwan), "get") # index (self)
    refute_supervisor_permission(employee_children_url(obiwan), "post", params: { child: {
        first_name: 'Little', last_name: 'Skywalker', birth_date: '2017-01-02',
            is_student: 'false' }})  # create
    refute_supervisor_permission(new_employee_child_url(obiwan), "get") # new
    refute_supervisor_permission(edit_child_url(lilobi), "get") # edit
    refute_supervisor_permission(child_url(lilobi), "patch", params: { child: { first_name: 'Lukey' }}) # update
    refute_supervisor_permission(child_url(lilobi), "delete") # destroy
  end

  test "Supervisor: can't see add child links on employee#show" do
    login_supervisor(:Quigon)
    get employee_children_url(employees(:Obiwan))

    assert_select "a#add-child-link", false
    assert_select "a#edit-child-link", false
    assert_select "a#delete-child-link", false
  end

  test "Supervisor: can't see links on child#index" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Obiwan))

    assert_select "a#add-child-link", false
  end

  #### Admin ####

  test "Children : Admin"  do
    login_admin(:MaceWindu)

    obiwan = employees(:Obiwan)
    lilobi = children(:LilObi)

    assert_admin_permission(employee_children_url(obiwan), "get") # index (self)
    assert_admin_permission(employee_children_url(obiwan), "post", params: { child: {
        first_name: 'Little', last_name: 'Skywalker', birth_date: '2017-01-02',
            is_student: 'false' }})  # create
    assert_admin_permission(new_employee_child_url(obiwan), "get") # new
    assert_admin_permission(edit_child_url(lilobi), "get") # edit
    assert_admin_permission(child_url(lilobi), "patch", params: { child: { first_name: 'Lukey' }}) # update
    assert_admin_permission(child_url(lilobi), "delete") # destroy
  end

  test "Admin: can see add child links on employee#show" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Han))

    assert_select "a#add-child-link"
  end

  test "Admin: can see add child links on child#index" do
    login_admin(:MaceWindu)
    get employee_children_url(employees(:Han))

    assert_select "a#add-child-link"
    assert_select "a#edit-child-link"
    assert_select "a#delete-child-link"
  end

end
