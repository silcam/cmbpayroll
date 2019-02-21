require "test_helper"

class WorkHoursControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  test "WorkHours calendar displays all days" do
    luke_emp = employees(:Luke)
    login_admin(:MaceWindu)

    set_last_posted_period(2018,3)
    get employee_work_hours_url(luke_emp)
    assert_response :success
    assert_select "h5#1-Apr-18", true
    assert_select "h5#30-Apr-18", true

    set_last_posted_period(2018,11)
    get employee_work_hours_url(luke_emp)
    assert_response :success
    assert_select "h5#1-Dec-18", true
    assert_select "h5#31-Dec-18", true

    set_last_posted_period(2018,12)
    get employee_work_hours_url(luke_emp)
    assert_response :success
    assert_select "h5#1-Jan-19", true
    assert_select "h5#31-Jan-19", true

    set_last_posted_period(2018,9)
    get employee_work_hours_url(luke_emp)
    #In order to see the page content.
    #Rails.logger.error("#{@response.body}")
    assert_response :success
    assert_select "h5#1-Oct-18", true
    assert_select "h5#31-Oct-18", true
  end

  #### USER ####

  test "WorkHours : User"  do
    login_user(:Luke)

    luke_emp = employees(:Luke)
    refute_user_permission(work_hours_url(), "get") # work_hours#index
    assert_user_permission(employee_work_hours_url(luke_emp), "get") # employee_work_hours#index
    refute_user_permission(edit_employee_work_hours_url(luke_emp), "get") # employee_work_hours#edit
    refute_user_permission(update_employee_work_hours_url(luke_emp), "post", params: {
      'hours[2017-09-01]': '8' }) # employee_work_hours#update
  end

  test "USER: can't see add hours link on employee#show" do
    login_user(:Luke)
    get employee_url(employees(:Luke))

    assert_select "a#add-hours-link", false
  end

  test "USER: can't see add hours link on work_hours#index" do
    login_user(:Luke)
    get employee_work_hours_url(employees(:Luke))

    assert_select "a#enter-hours-btn", false
  end

  test "User: can't see link on home#home" do
    login_user(:Luke)
    get root_url()

    assert_select "a#hours-link", false
  end

  #### Supervisor ####

  test "WorkHours : Supervisor"  do
    login_supervisor(:Quigon)

    obiwan = employees(:Obiwan)
    refute_supervisor_permission(work_hours_url(), "get") # work_hours#index
    assert_supervisor_permission(employee_work_hours_url(obiwan), "get") # employee_work_hours#index
    refute_supervisor_permission(edit_employee_work_hours_url(obiwan), "get") # employee_work_hours#edit
    refute_supervisor_permission(update_employee_work_hours_url(obiwan), "post", params: {
      'hours[2017-09-01]': '8' }) # employee_work_hours#update
  end

  test "Supervisor: can't see add hours link on employee#show" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Obiwan))

    assert_select "a#add-hours-link", false
  end

  test "Supervisor: can't see add hours link on work_hours#index" do
    login_supervisor(:Quigon)
    get employee_work_hours_url(employees(:Obiwan))

    assert_select "a#enter-hours-btn", false
  end

  test "Supervisor: can't see link on home#home" do
    login_supervisor(:Quigon)
    get root_url()

    assert_select "a#hours-link", false
  end

  #### Admin ####

  test "WorkHours : Admin"  do
    login_admin(:MaceWindu)

    han = employees(:Han)
    assert_supervisor_permission(work_hours_url(), "get") # work_hours#index
    assert_supervisor_permission(employee_work_hours_url(han), "get") # employee_work_hours#index
    assert_supervisor_permission(edit_employee_work_hours_url(han), "get") # employee_work_hours#edit
    assert_supervisor_permission(update_employee_work_hours_url(han), "post", params: {
      'hours[2017-09-01]': {hours: '8'} }) # employee_work_hours#update
  end

  test "Admin: can't see add hours link on employee#show" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Han))

    assert_select "a#add-hours-link"
  end

  test "Admin: can't see add hours link on work_hours#index" do
    login_admin(:MaceWindu)
    get employee_work_hours_url(employees(:Han))

    assert_select "a#enter-hours-btn"
  end

  test "Admin: can't see add hours link on home#home" do
    login_admin(:MaceWindu)
    get root_url()

    assert_select "a#hours-link"
  end

end
