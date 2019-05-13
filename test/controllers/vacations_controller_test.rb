require "test_helper"

class VacationsControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  test "Vacation Voucher Display" do
    login_admin(:MaceWindu)
    get root_url()
    assert_response :success

    luke_emp = employees(:Luke)
    luke_vacay = luke_emp.vacations.create!(start_date: '2017-10-15', end_date: '2017-10-18')

    get print_voucher_vacation_url(luke_vacay, :format => :pdf)
    assert_response :success

    luke_new_vacay = luke_emp.vacations.create!(start_date: '2022-10-15', end_date: '2022-10-18')

    get print_voucher_vacation_url(luke_new_vacay, :format => :pdf)
    assert_response :success
  end

  #### USER ####

  test "Vacations : User" do
    login_user(:Luke)

    luke_emp = employees(:Luke)
    luke_vacay = luke_emp.vacations.create!(start_date: '2017-10-15', end_date: '2017-10-18')

    refute_user_permission(vacations_url(), "get") # vacations#index
    refute_user_permission(vacations_url(), "post", params: { vacation: {
      'employee_id': luke_emp.id, 'start_date': '2017-10-01', 'end_date': '2017-10-05'
        }}) # vacations#create
    refute_user_permission(new_vacation_url(), "get") # vacations#new
    refute_user_permission(edit_vacation_url(luke_vacay), "get") # vacations#edit
    refute_user_permission(vacation_url(luke_vacay), "patch", params: { vacation: {
      'end_date': '2017-10-06' }}) # vacations#update
    refute_user_permission(vacation_url(luke_vacay), "delete") # vacations#destroy

    assert_user_permission(days_summary_employee_vacations_url(luke_emp), "get") #vacation#days_summary
    assert_user_permission(employee_vacations_url(luke_emp), "get") # vacation#index
    refute_user_permission(employee_vacations_url(luke_emp), "post", params: { vacation: {
      'start_date': '2017-10-01', 'end_date': '2017-10-05' }}) # vacations#create
    refute_user_permission(new_employee_vacation_url(luke_emp), "get") # vacations#new
  end

  test "User: can't see link on home#home" do
    login_user(:Luke)
    get root_url()

    assert_select "a#vacations-link", false
  end

  test "User: can't see link on employee#show" do
    login_user(:Luke)
    get employee_url(employees(:Luke))

    assert_select "a#add-vacation-link", false
  end

  test "User: can't see button on vacation#index" do
    login_user(:Luke)
    get employee_vacations_url(employees(:Luke))

    assert_select "a#enter-vacation-btn", false
  end

  #### Supervisor ####

  test "Vacations : Supervisor"  do
    login_supervisor(:Quigon)

    obiwan = employees(:Obiwan)
    obiwan_vacay = obiwan.vacations.create!(start_date: '2017-10-15', end_date: '2017-10-18')
    han = employees(:Han)

    refute_supervisor_permission(vacations_url(), "get") # vacations#index
    refute_supervisor_permission(vacations_url(), "post", params: { vacation: {
      'employee_id': obiwan.id, 'start_date': '2017-10-01', 'end_date': '2017-10-05'
        }}) # vacations#create
    refute_supervisor_permission(new_vacation_url(), "get") # vacations#new
    refute_supervisor_permission(edit_vacation_url(obiwan_vacay), "get") # vacations#edit
    refute_supervisor_permission(vacation_url(obiwan_vacay), "patch", params: { vacation: {
      'end_date': '2017-10-06' }}) # vacations#update
    refute_supervisor_permission(vacation_url(obiwan_vacay), "delete") # vacations#destroy

    assert_supervisor_permission(days_summary_employee_vacations_url(obiwan), "get") #vacation#days_summary
    refute_supervisor_permission(days_summary_employee_vacations_url(han), "get") #vacation#days_summary
    assert_supervisor_permission(employee_vacations_url(obiwan), "get") # vacation#index
    refute_supervisor_permission(employee_vacations_url(han), "get") # vacation#index
    refute_supervisor_permission(employee_vacations_url(obiwan), "post", params: { vacation: {
      'start_date': '2017-10-01', 'end_date': '2017-10-05' }}) # vacations#create
    refute_supervisor_permission(new_employee_vacation_url(obiwan), "get") # vacations#new
  end

  test "Supervisor: can't see link on home#home" do
    login_supervisor(:Quigon)
    get root_url()

    assert_select "a#vacations-link", false
  end

  test "Supervisor: can't see link on employee#show" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Obiwan))

    assert_select "a#add-vacation-link", false
  end

  test "Supervisor: can't see button on vacation#index" do
    login_supervisor(:Quigon)
    get employee_vacations_url(employees(:Obiwan))

    assert_select "a#enter-vacation-btn", false
  end

  #### Admin ####

  test "Vacations : Admin"  do
    login_admin(:MaceWindu)

    han = employees(:Han)
    han_vacay = han.vacations.create!(start_date: '2017-10-15', end_date: '2017-10-18')

    assert_supervisor_permission(vacations_url(), "get") # vacations#index
    assert_supervisor_permission(vacations_url(), "post", params: { vacation: {
      'employee_id': han.id, 'start_date': '2017-10-01', 'end_date': '2017-10-05'
        }}) # vacations#create
    assert_supervisor_permission(new_vacation_url(), "get") # vacations#new
    assert_supervisor_permission(edit_vacation_url(han_vacay), "get") # vacations#edit
    assert_supervisor_permission(vacation_url(han_vacay), "patch", params: { vacation: {
      'end_date': '2017-10-06' }}) # vacations#update
    assert_supervisor_permission(vacation_url(han_vacay), "delete") # vacations#destroy

    assert_supervisor_permission(days_summary_employee_vacations_url(han), "get") #vacation#days_summary
    assert_supervisor_permission(employee_vacations_url(han), "get") # vacation#index
    assert_supervisor_permission(employee_vacations_url(han), "post", params: { vacation: {
      'start_date': '2017-10-01', 'end_date': '2017-10-05' }}) # vacations#create
    assert_supervisor_permission(new_employee_vacation_url(han), "get") # vacations#new
  end

  test "Admin: can see link on home#home" do
    login_admin(:MaceWindu)
    get root_url()

    assert_select "a#vacations-link"
  end

  test "Admin: can't see link on employee#show" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Han))

    assert_select "a#add-vacation-link"
  end

  test "Admin: can't see button on vacation#index" do
    login_admin(:MaceWindu)
    get employee_vacations_url(employees(:Han))

    assert_select "a#enter-vacation-btn"
  end

end
