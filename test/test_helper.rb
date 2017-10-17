require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'minitest/reporters'
require 'minitest/rails/capybara'

Minitest::Reporters.use!

`rails db:seed`

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def model_validation_hack_test(model, params)
    params.each_key do |param|
      test_params = params.clone
      test_params.delete(param)
      shouldnt_save = model.new(test_params)
      refute shouldnt_save.save, "Should not save #{model} without #{param}"
    end
    should_save = model.new(params)
    assert should_save.save, "Should save #{model} with valid params"
  end

  def log_in_luke
    visit login_path
    fill_in 'Username', with: 'luke'
    fill_in 'Password', with: 'luke'
    click_button 'Log in'
  end

  def on_sep_5
    Date.stub :today, Date.new(2017, 9, 5) do
      yield
    end
  end

  def return_valid_employee
    employee = Employee.new
    employee.first_name = "Playslip"
    employee.last_name = "Recipient"
    employee.title = "Title"
    employee.department = departments :Admin
    employee.hours_day = 23
    employee.supervisor = supervisors :Yoda
    employee.first_day = '2010-07-11'
    employee.contract_start = '2010-07-11'

    employee.category_three!
    employee.echelon_d!

    employee.save

    return employee
  end

  def create_earnings(payslip)
    earnings = Earning.new

    # default data for a valid object
    earnings.hours = 1
    earnings.rate = 1

    payslip.earnings << earnings
  end

  def random_string(length=10)
    return (0..length-1).map { (65 + rand(26)).chr }.join
  end

  # Assumes no holidays
  def generate_work_hours(employee, period)
    (period.start .. period.finish).each do |date|
      hours = WorkHour.default_hours date, nil
      employee.work_hours.create!(date: date, hours: hours)
    end
  end
end

module ControllerTestHelper

  def login_user(user_sym)
    login(user_sym, "user")
  end

  def login_supervisor(user_sym)
    login(user_sym, "supervisor")
  end

  def login_admin(user_sym)
    login(user_sym, "admin")
  end

  def login(user_sym, role_sym=nil)
    luke = users(user_sym)
    unless (role_sym.nil?)
      assert_equal(role_sym, luke.role, "incorrect role")
    end
    sign_in_as(luke)
  end

  def sign_in_as(user)
    https!
    get "/login"
    assert_response :success

    post "/login", params: { username: user.username, password: user.username }
    follow_redirect!
    assert_equal '/', path

    https!(false)
  end

  def verify_is_supervisor(supervisor_sym, employee_sym)
    supervisor = supervisors(supervisor_sym)
    employee = employees(employee_sym)

    assert_equal(supervisor.person, employee.supervisor.person, "verify relationship")
  end

  def assert_user_permission(url, method, params=nil)
    assert_permission("User", url, method, params)
  end

  def assert_supervisor_permission(url, method, params=nil)
    assert_permission("Supervisor", url, method, params)
  end

  def assert_admin_permission(url, method, params=nil)
    assert_permission("Admin", url, method, params)
  end

  def refute_user_permission(url, method, params=nil)
    refute_permission("User", url, method, params)
  end

  def refute_supervisor_permission(url, method, params=nil)
    refute_permission("Supervisor", url, method, params)
  end

  def refute_admin_permission(url, method, params=nil)
    refute_permission("Admin", url, method, params)
  end

  def assert_permission(role, url, method, params=nil)
    make_call(url, method, params)

    begin
      refute_permissions_error
    rescue MiniTest::Assertion
      raise MiniTest::Assertion, "failed checking role: #{role}, for #{method}: #{url}"
    end
  end

  def refute_permission(role, url, method, params=nil)
    make_call(url, method, params)

    begin
      assert_permissions_error
    rescue MiniTest::Assertion
      raise MiniTest::Assertion, "failed checking role: #{role}, for #{method}: #{url}"
    end
  end

  def assert_permissions_error
    assert_response :redirect
    follow_redirect!

    assert_select "p#permissions-error", "You cannot perform this action."
  end

  def refute_permissions_error
    if (@response.status >= 300 && @response.status < 400)
      follow_redirect!
    end

    assert_response :success
    assert_select "p#permissions-error", false
  end

  def make_call(url, method, params=nil)
    if ("get" == method)
      get url
    elsif ("post" == method)
      post url, params
    elsif ("patch" == method)
      patch url, params
    elsif ("delete" == method)
      delete url
    end
  end

end
