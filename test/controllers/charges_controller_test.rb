require "test_helper"

class ChargesControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### USER ####

  test "Things a User CANNOT do"  do
    login_user(:Luke)

    luke_emp = employees(:Luke)
    refute_user_permission(new_employee_charge_url(luke_emp), "get") # new
    refute_user_permission(employee_charges_url(luke_emp), "post", params: { note: 'Test Charge', amount: 1500, date: Date.today }) # create
    assert_user_permission(employee_charges_url(luke_emp), "get") # index
    refute_user_permission(charge_url(Charge.all.first), "delete") # delete charge
  end

  test "USER: can't see add charge link on employee#index" do
    login(:Luke, "user")
    get employees_url()

    assert_select "a.add-charge-link", false
  end

  test "USER: can't see add charge link on employee#show" do
    login(:Luke, "user")
    get employee_url(employees(:Luke))

    assert_select "a#add-charge-link", false
  end

  test "USER: can't see add charge link on charges#index" do
    login(:Luke, "user")
    get employee_charges_url(employees(:Luke))

    assert_select "a#add-charge-btn", false
  end

  #### SUPERVISOR ####

  test "Things a supervisor CANNOT do"  do
    login_supervisor(:Quigon)

    obiwan = employees(:Obiwan)
    obiwan_charge = obiwan.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(obiwan.charges.size >= 1, "obiwan has charges")

    refute_supervisor_permission(new_employee_charge_url(employees(:Obiwan)), "get") # new (report)
    refute_supervisor_permission(employee_charges_url(employees(:Obiwan)), "post", params: { note: 'Test Charge', amount: 1500, date: Date.today }) # create
    assert_supervisor_permission(employee_charges_url(employees(:Obiwan)), "get") # index (report)
    refute_supervisor_permission(employee_charges_url(employees(:Han)), "get") # index (non-report)
    refute_supervisor_permission(charge_url(obiwan_charge), "delete") # delete charge (report)
  end

  test "Supervisor: can't see add charge link on index" do
    login_supervisor(:Quigon)
    get employees_url()

    assert_select "a.add-charge-link", false
  end

  test "Supervisor: can't see add charge link on employee#show" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Obiwan))

    assert_select "a#add-charge-link", false
  end

  test "Supervisor: can't see add charge link on charges#index" do
    login_supervisor(:Quigon)
    get employee_charges_url(employees(:Obiwan))

    assert_select "a#add-charge-btn", false
  end

  #### ADMIN ####

  test "Admin can do things" do
    login_admin(:MaceWindu)

    luke_emp = employees(:Luke)
    luke_charge = luke_emp.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(luke_emp.charges.size >= 1, "luke has charges")

    assert_admin_permission(new_employee_charge_url(luke_emp), "get") # new
    assert_admin_permission(employee_charges_url(luke_emp), "post", params: { charge: { note: 'Test Charge', amount: 1500, date: Date.today }}) # create
    assert_admin_permission(employee_charges_url(luke_emp), "get") # index
    assert_admin_permission(charge_url(luke_charge), "delete") # delete charge
  end

  test "Admin: can see add charge link on employee#show" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Obiwan))

    assert_select "a#add-charge-link"
  end

  test "Admin: can see add charge link on charges#index" do
    login_admin(:MaceWindu)
    get employee_charges_url(employees(:Han))

    assert_select "a#add-charge-btn"
  end
end
