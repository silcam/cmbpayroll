require "test_helper"

class EmployeeTest < ActiveSupport::TestCase

  def setup
    @luke = employees :Luke
  end

  test "Employee has association" do
    t = Employee.reflect_on_association(:children).macro == :has_many
    t = Employee.reflect_on_association(:transactions).macro == :has_many
  end

  test "Associations" do
    lukes_coke = transactions :LukesCoke
    assert_includes @luke.transactions, lukes_coke
  end

  test "validations" do
    params = {
        first_name: 'Joe',
        last_name: 'Shmoe',
        title: 'Director',
        department: 'Computer Services',
        hours_day: 12
    }

    model_validation_hack_test Employee, params
  end

  test "conditional_wage_validation" do
    employee = Employee.new

    employee.first_name = "Joe"
    employee.last_name = "Smith"
    employee.title = "Director of Himself"
    employee.department = "Computer Services"
    employee.hours_day = 12
    employee.echelon = "a"

    assert(employee.valid?, "initial valid state")

    # needs to be set if the echelon is 'g'
    employee.echelon = "g"
    refute(employee.valid?, "should not be valid if echelon g without wage")

    employee.wage = "123456"
    assert(employee.valid?, "echelon g and wage is AOK")
  end


  test "enum_validations" do
    employee = Employee.new

    employee.first_name = "Joe"
    employee.last_name = "Smith"
    employee.title = "Director of Himself"
    employee.department = "Computer Services"

    employee.hours_day = 12

    employee.employment_status = "full_time"
    employee.gender = "male"
    employee.marital_status = "married"
    employee.days_week = "five"

    assert employee.valid?

    ## EMPLOYMENT STATUS
    assert_raise(ArgumentError) do
      employee.employment_status = "none"
    end

    employee.employment_status = "part_time"

    assert employee.errors.empty?
    Rails.logger.error(employee.errors.messages)
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
    employee = Employee.new

    employee.first_name = "Joe"
    employee.last_name = "Smith"
    employee.title = "Directork of Himself"
    employee.department = "Computer Services"

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

  test "Full Name" do
    assert_equal "Luke Skywalker", @luke.full_name
  end

  test "Full Name Rev" do
    assert_equal "Skywalker, Luke", @luke.full_name_rev
  end
end
