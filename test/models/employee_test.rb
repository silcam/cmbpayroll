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
    assert_equal(0, employee.amical_amount)

    employee.amical = true
    assert_equal(3000, employee.amical_amount)

    new_amical_value = 1234567
    SystemVariable.create!(key: 'amical_amount', value: new_amical_value)
    assert_equal(new_amical_value, employee.amical_amount)
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
