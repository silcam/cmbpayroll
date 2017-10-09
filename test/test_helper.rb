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
