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

  def log_in(user)
    visit login_path
    fill_in 'Username', with: user.username
    fill_in 'Password', with: user.username
    click_button 'Log in'
  end

  def log_in_luke
    log_in users(:Luke)
  end

  def log_in_admin
    visit login_path
    fill_in 'Username', with: 'mace'
    fill_in 'Password', with: 'mace'
    click_button 'Log in'
  end

  def on_sep_5
    Date.stub :today, Date.new(2017, 9, 5) do
      yield
    end
  end

  def return_valid_employee
    # this employee's wage is: 73565
    #            base wage is: 58280
    employee = Employee.new
    employee.first_name = "Playslip"
    employee.last_name = "Recipient"
    employee.title = "Title"
    employee.employment_status = "full_time"
    employee.department = departments :Admin
    employee.wage_period = "monthly"
    employee.hours_day = 8
    employee.days_week = "five"
    employee.transportation = 5000
    employee.supervisor = supervisors :Yoda
    employee.first_day = '2010-07-11'
    employee.contract_start = '2010-07-11'
    employee.amical = 3000
    employee.uniondues = true

    employee.category_three!
    employee.echelon_d!

    employee.save

    return employee
  end

  def create_and_return_payslip(employee)
    # check posted period
    period = LastPostedPeriod.get
    period = Period.current if period.nil?
    period = period.next
    refute(LastPostedPeriod.posted?(period))

    # work hours
    generate_work_hours(employee, period)

    # process payslip
    payslip = Payslip.process(employee, period)
    payslip.save

    assert(payslip.valid?, "payslip should be valid (Does the employee have category and echelon set??)")
    assert(payslip.id, "payslip should exist (is it valid??)")

    payslip
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
    login_user = users(user_sym)
    unless (role_sym.nil?)
      assert(login_user.send("#{role_sym}?"), "incorrect role")
    end
    sign_in_as(login_user)
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
      raise MiniTest::Assertion, "Should've been able to #{method.upcase} #{url} (role: #{role})"
    end
  end

  def refute_permission(role, url, method, params=nil)
    make_call(url, method, params)

    begin
      assert_permissions_error
    rescue MiniTest::Assertion
      raise MiniTest::Assertion, "Shouldn't have been able to #{method.upcase} #{url} (role: #{role})"
    end
  end

  def assert_permissions_error
    assert_response :redirect
    follow_redirect!

    assert_select "p#permissions-error", "You cannot perform this action."
  end

  def refute_permissions_error
    while (@response.status >= 300 && @response.status < 400)
      follow_redirect!
    end

    assert_response :success
    assert_select "p#permissions-error", false
  end

  def make_call(url, method, params=nil)
    if ("get" == method.downcase)
      get url
    elsif ("post" == method.downcase)
      post url, params
    elsif ("patch" == method.downcase)
      patch url, params
    elsif ("delete" == method.downcase)
      delete url
    end
  end

end
