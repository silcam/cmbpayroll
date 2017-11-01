require "test_helper"

class EmployeeTest < ActiveSupport::TestCase

  def setup
    @luke = employees :Luke
    @yoda = supervisors :Yoda
    @admin = departments :Admin
  end

  test "Employee has association" do
    t = Employee.reflect_on_association(:children).macro == :has_many
    t = Employee.reflect_on_association(:charges).macro == :has_many
  end

  test "Associations" do
    lukes_coke = charges :LukesCoke
    luke_jr = children :LukeJr
    dept = departments :Admin

    assert_includes @luke.charges, lukes_coke
    assert_equal @yoda, @luke.supervisor
    assert_equal @admin, @luke.department
    assert_includes @luke.children, luke_jr
  end

  test "Destroy with Department" do
    @emp = return_valid_employee()

    dept = Department.new
    dept.name = "TEST"
    dept.description = "TEST"
    dept.account = "TEST"
    dept.save

    @emp.department = dept
    @emp.save

    assert @emp.destroy

    refute_nil dept.id
    refute_nil dept
  end

  test "validations" do
    model_validation_hack_test Employee, some_valid_params
  end

  test "conditional_wage_validation" do
    employee = Employee.new(some_valid_params(echelon: :a))

    assert(employee.valid?, "initial valid state")

    # needs to be set if the echelon is 'g'
    employee.echelon = :g
    refute(employee.valid?, "should not be valid if echelon g without wage")

    employee.wage = "123456"
    assert(employee.valid?, "echelon g and wage is AOK")
  end


  test "enum_validations" do
    employee = Employee.new(some_valid_params(employment_status: :full_time,
                                              gender: :male,
                                              marital_status: :married,
                                              days_week: :five))


    assert employee.valid?

    ## EMPLOYMENT STATUS
    assert_raise(ArgumentError) do
      employee.employment_status = "none"
    end

    employee.employment_status = "part_time"

    assert employee.errors.empty?
    Rails.logger.debug(employee.errors.messages)
    assert employee.valid?

    ## GENDER
    assert_raise(ArgumentError) do
      employee.gender = "none"
    end

    employee.gender = "female"

    assert employee.valid?
    assert employee.errors.empty?

    ## MARITAL STATUS
    assert_raise(ArgumentError) do
      employee.marital_status = "divorced"
    end

    employee.marital_status = "married"

    assert employee.valid?
    assert employee.errors.empty?

    ## DAYS PER WEEK
    assert_raise(ArgumentError, "not a beatle") do
      employee.days_week = "eight"
    end

    employee.days_week = "five"

    refute employee.six_day?
    assert employee.five_day?
    assert employee.valid?
    assert employee.errors.empty?

    ## CATEGORY
    assert_raise(ArgumentError) do
      employee.category = "twenty"
    end

    employee.category = "two"

    assert employee.category_two?
    assert employee.valid?
    assert employee.errors.empty?

    ## ECHELON
    assert_raise(ArgumentError) do
      employee.echelon = "x"
    end

    employee.echelon = "a"

    assert employee.echelon_a?
    assert employee.valid?
    assert employee.errors.empty?
  end

  test "numeric_validations" do
    employee = Employee.new some_valid_params

    employee.hours_day = "-2"

    refute employee.valid?
    refute employee.errors[:hours_day].nil?

    employee.hours_day = "983"

    refute employee.valid?
    refute employee.errors[:hours_day].nil?

    employee.hours_day = "12"

    assert employee.valid?
    assert employee.errors.empty?
  end

  test "Compute Advance" do
    employee = return_valid_employee()
    employee.category = "one"
    employee.echelon = "g"

    # normally half
    employee.wage = 20000
    assert_equal(10000, employee.advance_amount())

    # round up? TODO: correct?
    employee.wage = 2555
    assert_equal(1278, employee.advance_amount())
  end

  test "Full Name" do
    assert_equal "Luke Skywalker", @luke.full_name
  end

  test "Full Name Rev" do
    assert_equal "Skywalker, Luke", @luke.full_name_rev
  end

  test "Find_wage_by_attributes" do
    employee = return_valid_employee()

    employee.category = "three"
    employee.echelon = "six"

    assert_equal(83755, employee.find_wage())

  end

  test "AMICAL" do
    employee = return_valid_employee()
    assert_equal(nil, employee.amical)

    employee.amical = 3000
    assert_equal(3000, employee.amical)
  end

  test "union dues" do
    employee = return_valid_employee()
    assert_equal(0, employee.union_dues_amount)

    employee.wage = 10000
    employee.category_one!
    employee.echelon_g!

    employee.uniondues = true
    assert_equal(100, employee.union_dues_amount)

    new_union_dues = 0.76
    SystemVariable.create!(key: 'union_dues', value: new_union_dues)
    assert_equal(employee.wage * new_union_dues, employee.union_dues_amount)
  end

  test "deductable_expenses" do
    employee = return_valid_employee()

    employee.amical = 3000
    employee.uniondues = true

    expenses_hash = employee.deductable_expenses()
    assert_equal(2, expenses_hash.length)

    employee.amical = 3000
    employee.uniondues = false

    expenses_hash = employee.deductable_expenses()
    assert_equal(2, expenses_hash.length)

    assert(expenses_hash[:amical])

    assert_equal(:amical, expenses_hash[:amical])
    assert_equal(:union_dues_amount, expenses_hash[:union])

    assert_equal(3000, employee.send(expenses_hash[:amical]))
    assert_equal(0, employee.send(expenses_hash[:union]))
  end

  test "servicetime" do
    employee1 = return_valid_employee()

    employee1.contract_start = Date.new(2017,1,1)
    period = Period.new(2017,03)
    assert_equal(0, employee1.servicetime(period), "2017-01-01 -> 2017-03-31 is 0 years")

    employee1.contract_start = Date.new(2016,1,1)
    period = Period.new(2017,03)
    assert_equal(1, employee1.servicetime(period), "2016-01-01 -> 2017-03-31 is 1 years")

    employee1.contract_start = Date.new(2016,1,1)
    period = Period.new(2017,03)
    assert_equal(1, employee1.servicetime(period), "2016-01-01 -> 2017-03-31 is 1 years")

    employee1.contract_start = Date.new(2017,1,1)
    period = Period.new(2013,03)
    assert_equal(-3, employee1.servicetime(period), "2017-01-01 -> 2013-03-31 is -3 years")

    employee1.contract_start = Date.new(2016,3,31)
    period = Period.new(2017,03)
    assert_equal(1, employee1.servicetime(period), "2016-03-31 -> 2017-03-31 is 1 year")

    employee1.contract_start = Date.new(2016,2,1)
    period = Period.new(2017,02)
    assert_equal(1, employee1.servicetime(period), "2016-02-01 -> 2017-02-28 is 1 year")

    employee1.contract_start = Date.new(2015,2,28)
    period = Period.new(2016,02) # leap year tests
    assert_equal(1, employee1.servicetime(period), "2015-02-28 -> 2016-02-29 is 1 years")

    employee1.contract_start = Date.new(2016,2,29)
    period = Period.new(2017,02) # leap year tests (this is 365 days, thus a year)
    assert_equal(1, employee1.servicetime(period), "2016-02-29 -> 2017-02-28 is 1 years")

    employee1.contract_start = Date.new(2014,1,31)
    period = Period.new(2017,03)
    assert_equal(3, employee1.servicetime(period), "2014-01-31 -> 2017-03-31 is 3 years")

    employee1.contract_start = Date.new(2014,4,30)
    period = Period.new(2017,03)
    assert_equal(2, employee1.servicetime(period), "2014-04-30 -> 2017-03-31 is 2 years")
  end

  test "convert_days_week" do
    employee1 = return_valid_employee()

    employee1.days_week = "five"
    assert_equal(5, employee1.convert_days_week)

    employee1.days_week = "one"
    assert_equal(1, employee1.convert_days_week)

    employee1.days_week = "seven"
    assert_equal(7, employee1.convert_days_week)
  end

  test "hours_per_month" do
    employee1 = return_valid_employee()

    employee1.hours_day = 3
    employee1.days_week = "five"
    assert_equal(65, employee1.hours_per_month)

    employee1.hours_day = 7
    employee1.days_week = "six"
    assert_equal(182, employee1.hours_per_month)
  end

  test "work days per month" do
    employee1 = return_valid_employee()

    employee1.hours_day = 8
    employee1.days_week = "five"

    leapfeb16 = Period.new(2016,2)
    feb17 = Period.new(2017,2)
    sep17 = Period.new(2017,9)
    dec17 = Period.new(2017,12)

    assert_equal(21, employee1.workdays_per_month(leapfeb16))
    assert_equal(20, employee1.workdays_per_month(feb17))
    assert_equal(21, employee1.workdays_per_month(sep17))
    assert_equal(21, employee1.workdays_per_month(dec17))

    employee1.days_week = "six"

    assert_equal(25, employee1.workdays_per_month(leapfeb16))
    assert_equal(24, employee1.workdays_per_month(feb17))
    assert_equal(26, employee1.workdays_per_month(sep17))
    assert_equal(26, employee1.workdays_per_month(dec17))

    employee1.days_week = "four"

    assert_equal(17, employee1.workdays_per_month(leapfeb16))
    assert_equal(16, employee1.workdays_per_month(feb17))
    assert_equal(16, employee1.workdays_per_month(sep17))
    assert_equal(16, employee1.workdays_per_month(dec17))
  end

  def some_valid_params(params={})
    {first_name: 'Joe',
     last_name: 'Shmoe',
     title: 'Director',
     department: @admin,
     hours_day: 12,
     supervisor: @yoda}.merge params
  end
end
