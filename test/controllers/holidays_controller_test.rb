require "test_helper"

class HolidaysControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  def setup
    @holiday = Holiday.create!(name: 'January Thirteenth', date: '2017-01-13')
  end

  #### USER ####

  test "Holidays: User" do
    login_user(:Luke)

    refute_user_permission(holidays_url(), "get") # index
    refute_user_permission(holidays_url(), "post", params: { holiday: { name: 'Halloween', date: '2017-10-31' }}) # create
    refute_user_permission(edit_holiday_url(@holiday), "get") # edit
    refute_user_permission(holiday_url(@holiday), "patch", params: { holiday: { name: 'Halloween', date: '2017-10-31' }}) # update
    refute_user_permission(holiday_url(@holiday), "delete") # destroy
    refute_user_permission(holidays_url("2018"), "post", params: { submit: "yes" }) # generate
  end

  #### Supervisor ####

  test "Holidays: Supervisor" do
    login_supervisor(:Quigon)

    refute_supervisor_permission(holidays_url(), "get") # index
    refute_supervisor_permission(holidays_url(), "post", params: { holiday: { name: 'Halloween', date: '2017-10-31' }}) # create
    refute_supervisor_permission(edit_holiday_url(@holiday), "get") # edit
    refute_supervisor_permission(holiday_url(@holiday), "patch", params: { holiday: { name: 'Halloween', date: '2017-10-31' }}) # update
    refute_supervisor_permission(holiday_url(@holiday), "delete") # destroy
    refute_supervisor_permission(generate_holidays_url("2018"), "post", params: { submit: "yes" }) # generate
  end

  #### Admin ####

  test "Holidays: Admin" do
    login_admin(:MaceWindu)

    assert_admin_permission(holidays_url(), "get") # index
    assert_admin_permission(holidays_url(), "post", params: { holiday: { name: 'Halloween',
        'date(1i)': '2017', 'date(2i)': '10', 'date(3i)': '31',
          'observed(1i)': '1', 'observed(2i)': '', 'observed(3i)': '',
            'bridge(1i)': '1', 'bridge(2i)': '', 'bridge(3i)': '' }}) # create
    assert_admin_permission(edit_holiday_url(@holiday), "get") # edit
    assert_admin_permission(holiday_url(@holiday), "patch", params: { holiday: { name: 'New Halloween', 
        'date(1i)': '2017', 'date(2i)': '10', 'date(3i)': '31',
          'observed(1i)': '1', 'observed(2i)': '', 'observed(3i)': '',
            'bridge(1i)': '1', 'bridge(2i)': '', 'bridge(3i)': '' }}) # update
    assert_admin_permission(holiday_url(@holiday), "delete") # destroy
    assert_admin_permission(generate_holidays_url("2018"), "post", params: { submit: "yes" }) # generate
  end

end
