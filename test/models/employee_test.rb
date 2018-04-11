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

  test "Locations" do
    assert(@luke.valid?, "luke defaults to bro")
    assert_equal("bro", @luke.location, "luke defaults to bro")

    @luke.location = "nonrfis"
    assert(@luke.valid?)
    @luke.location = "rfis"
    assert(@luke.valid?)

    assert_raise(ArgumentError) do
      @luke.location = "lagos"
    end

    @luke.location = "bro"
    assert(@luke.valid?)

    @luke.location = "aviation"
    assert(@luke.valid?)

    assert_raise(ArgumentError) do
      @luke.location = "sanfrancisco"
    end

    @luke.location = "gnro"
    assert(@luke.valid?)
  end

  test "create_location_transfer?" do
    assert_equal("bro", @luke.location, "luke defaults to bro")
    assert(@luke.create_location_transfer?)

    @luke.location = "nonrfis"
    refute(@luke.create_location_transfer?)

    @luke.location = "rfis"
    refute(@luke.create_location_transfer?)

    @luke.location = "aviation"
    assert(@luke.create_location_transfer?)

    @luke.location = "gnro"
    assert(@luke.create_location_transfer?)
  end

  test "Location Scopes" do
    @anakin = employees :Anakin
    @chewie = employees :Chewie

    @luke.location = "nonrfis"
    @anakin.location = "nonrfis"
    @chewie.location = "bro"
    assert(@luke.save)
    assert(@anakin.save)
    assert(@chewie.save)
    assert_equal(2, Employee.nonrfis().count())
    assert_equal(2, Employee.rfis().count())
    assert_equal(1, Employee.bro().count())
    assert_equal(0, Employee.gnro().count())
    assert_equal(0, Employee.aviation().count())

    @luke.location = "aviation"
    @anakin.location = "gnro"
    assert(@luke.save)
    assert(@anakin.save)
    assert(@chewie.save)
    assert_equal(0, Employee.nonrfis().count())
    assert_equal(2, Employee.rfis().count())
    assert_equal(1, Employee.bro().count())
    assert_equal(1, Employee.gnro().count())
    assert_equal(1, Employee.aviation().count())
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

  test "active" do
    employee = return_valid_employee()

    employee.employment_status = "full_time"
    assert(employee.is_currently_paid?, "full time is currently_paid")

    employee.employment_status = "part_time"
    assert(employee.is_currently_paid?, "part time is currently_paid")

    employee.employment_status = "temporary"
    assert(employee.is_currently_paid?, "temporary is currently_paid")

    employee.employment_status = "leave"
    refute(employee.is_currently_paid?, "leave is not currently_paid")

    employee.employment_status = "terminated_to_year_end"
    refute(employee.is_currently_paid?, "TTYE is not currently_paid")

    employee.employment_status = "inactive"
    refute(employee.is_currently_paid?, "inactive is not currently_paid")
  end

  test "echelon enums" do
    employee = return_valid_employee()

    employee.echelon = "a"
    assert_equal("a", employee.echelon)

    employee.update! echelon: 14
    assert_equal("b", employee.echelon)

    employee.wage = 123456
    employee.update! echelon: 19
    assert_equal("g", employee.echelon)

    employee.wage = nil
    employee.echelon = 13
    assert_equal("a", employee.echelon)
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

    # WAGE SCALE
    assert_raise(ArgumentError) do
      employee.wage_scale = "one"
    end

    employee.wage_scale = "a"

    assert employee.wage_scale_a?
    assert employee.valid?
    assert employee.errors.empty?

    employee.wage_scale = "e"

    assert employee.wage_scale_e?
    assert employee.valid?
    assert employee.errors.empty?

    # Wage Period
    assert_raise(ArgumentError) do
      employee.wage_period = "sesquicentennially"
    end

    employee.wage_period = "hourly"

    assert_equal("hourly", employee.wage_period)
    assert employee.valid?
    assert employee.errors.empty?

    employee.wage_period = "monthly"

    assert_equal("monthly", employee.wage_period)
    assert employee.valid?
    assert employee.errors.empty?
  end

  test "Paid Monthly" do
    employee = Employee.new some_valid_params
    refute(employee.paid_monthly?)

    employee.wage_period = "monthly"
    assert(employee.paid_monthly?)

    employee.wage_period = "hourly"
    refute(employee.paid_monthly?)
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

  test "Find_wage_by_attributes and wage scale" do
    employee = return_valid_employee()

    employee.category = "three"
    employee.echelon = "e"
    employee.wage_scale = "a"

    assert_equal(78660, employee.find_wage())
    assert_equal(58280, employee.find_base_wage())

    employee.category = "three"
    employee.echelon = "d"
    employee.wage_scale = "b"

    assert_equal(40410, employee.find_wage())
    assert_equal(33425, employee.find_base_wage())

    employee.category = "three"
    employee.echelon = "c"
    employee.wage_scale = "c"

    assert_equal(27160, employee.find_wage())
    assert_equal(23080, employee.find_base_wage())

    employee.category = "nine"
    employee.echelon = "b"
    employee.wage_scale = "b"

    assert_equal(158110, employee.find_wage())
    assert_equal(145555, employee.find_base_wage())
  end

  test "Daily Rate" do
    employee = return_valid_employee()
    employee.hours_day = 8
    employee.days_week = "five"

    period = Period.new(2018,1)

    employee.category = "nine"
    employee.echelon = "b"
    employee.wage_scale = "b"

    assert_equal(158110, employee.find_wage())
    # 173 and 1/3
    assert_equal(Rational(520,3), employee.hours_per_month())
    assert_equal(912, employee.hourly_rate.round)
    assert_equal(7296, employee.daily_rate.round)
  end

  test "Hourly Rate" do
    employee = return_valid_employee()
    employee.hours_day = 8
    employee.days_week = "five"

    period = Period.new(2018,1)

    employee.category = "nine"
    employee.echelon = "d"
    employee.wage_scale = "b"

    assert_equal(183080, employee.find_wage())
    # 173 and 1/3
    assert_equal(Rational(520,3), employee.hours_per_month())
    assert_equal(1056, employee.hourly_rate.round)
  end

  test "AMICAL" do
    employee = return_valid_employee()
    employee.amical = nil
    assert_nil(employee.amical)

    employee.amical = 3000
    assert_equal(3000, employee.amical)
  end

  test "union dues" do
    employee = return_valid_employee()
    employee.uniondues = false;
    assert_equal(0, employee.union_dues_amount)

    employee.category_one!
    employee.echelon_a!
    employee.wage_scale = "a"

    employee.uniondues = true
    assert_equal(377, employee.union_dues_amount)

    new_union_dues = 0.76
    SystemVariable.create!(key: 'union_dues', value: new_union_dues)
    new_exp_dues = ( employee.find_base_wage * new_union_dues ).floor
    assert_equal(new_exp_dues, employee.union_dues_amount)
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

    assert(expenses_hash[Employee::AMICAL])

    assert_equal(:amical, expenses_hash[Employee::AMICAL])
    assert_equal(:union_dues_amount, expenses_hash[Employee::UNION])

    assert_equal(3000, employee.send(expenses_hash[Employee::AMICAL]))
    assert_equal(0, employee.send(expenses_hash[Employee::UNION]))
  end

  test "years_of_service" do
    employee1 = return_valid_employee()

    employee1.contract_start = nil
    period = Period.new(2017,03)
    assert_equal(0, employee1.years_of_service(period), "no contract start is 0 years")

    # with a nil period, this uses the current period which moved with real time
    # so fix on a certain date for this test.
    on_sep_5 do
      employee1.contract_start = Date.new(2017,1,1)
      assert_equal(0, employee1.years_of_service(nil), "no period is 0 years")
    end

    employee1.contract_start = Date.new(2017,1,1)
    period = Period.new(2017,03)
    assert_equal(0, employee1.years_of_service(period), "2017-01-01 -> 2017-03-31 is 0 years")

    employee1.contract_start = Date.new(2016,1,1)
    period = Period.new(2017,03)
    assert_equal(1, employee1.years_of_service(period), "2016-01-01 -> 2017-03-31 is 1 years")

    employee1.contract_start = Date.new(2016,1,1)
    period = Period.new(2017,03)
    assert_equal(1, employee1.years_of_service(period), "2016-01-01 -> 2017-03-31 is 1 years")

    employee1.contract_start = Date.new(2017,1,1)
    period = Period.new(2013,03)
    assert_equal(0, employee1.years_of_service(period), "2017-01-01 -> 2013-03-31 is -3 years")

    employee1.contract_start = Date.new(2016,3,31)
    period = Period.new(2017,03)
    assert_equal(1, employee1.years_of_service(period), "2016-03-31 -> 2017-03-31 is 1 year")

    employee1.contract_start = Date.new(2016,2,1)
    period = Period.new(2017,02)
    assert_equal(1, employee1.years_of_service(period), "2016-02-01 -> 2017-02-28 is 1 year")

    employee1.contract_start = Date.new(2015,2,28)
    period = Period.new(2016,02) # leap year tests
    assert_equal(1, employee1.years_of_service(period), "2015-02-28 -> 2016-02-29 is 1 years")

    employee1.contract_start = Date.new(2016,2,29)
    period = Period.new(2017,02) # leap year tests (this is 365 days, thus a year)
    assert_equal(0, employee1.years_of_service(period), "2016-02-29 -> 2017-02-28 is 0 years")

    employee1.contract_start = Date.new(2014,1,31)
    period = Period.new(2017,03)
    assert_equal(3, employee1.years_of_service(period), "2014-01-31 -> 2017-03-31 is 3 years")

    employee1.contract_start = Date.new(2014,4,30)
    period = Period.new(2017,03)
    assert_equal(2, employee1.years_of_service(period), "2014-04-30 -> 2017-03-31 is 2 years")

    employee1.contract_start = Date.new(1986,1,6)
    period = Period.new(2018,01)
    assert_equal(32, employee1.years_of_service(period), "1986-01-06 -> 2018-01-31 is 32 years")

    employee1.contract_start = Date.new(2016,2,1)
    period = Period.new(2018,01)
    assert_equal(1, employee1.years_of_service(period), "2016-02-01 -> 2018-01-31 is 1 year")

    employee1.contract_start = Date.new(2016,2,1)
    period = Period.new(2018,02)
    assert_equal(2, employee1.years_of_service(period), "2016-02-01 -> 2018-02-28 is 2 years")
  end

  test "Dept Severance" do
    employee = return_valid_employee()
    period = Period.new(2017,12)

    employee.contract_start = Date.new(2014,4,30)
    assert_equal(3, employee.years_of_service(period), "2014-04-30 -> 2017-12 is 3 years")
    assert_equal(0, employee.department_severance_rate(period), "0-4 years, 0%")

    employee.contract_start = Date.new(2010,4,30)
    assert_equal(7, employee.years_of_service(period), "2010-04-30 -> 2017-12 is 7 years")
    assert_equal(0.4, employee.department_severance_rate(period), "5-10 years, 40%")

    employee.contract_start = Date.new(2005,4,30)
    assert_equal(12, employee.years_of_service(period), "2005-04-30 -> 2017-12 is 12 years")
    assert_equal(0.55, employee.department_severance_rate(period), "11-15 years, 55%")

    employee.contract_start = Date.new(1990,4,30)
    assert_equal(27, employee.years_of_service(period), "1990-04-30 -> 2017-12 is 27 years")
    assert_equal(0.6, employee.department_severance_rate(period), "15+ years, 60%")
  end

  test "convert_days_week" do
    employee1 = return_valid_employee()

    employee1.days_week = "five"
    assert_equal(5, employee1.days_week_to_i)

    employee1.days_week = "one"
    assert_equal(1, employee1.days_week_to_i)

    employee1.days_week = "seven"
    assert_equal(7, employee1.days_week_to_i)
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

  test "number of children under 6 and 19" do
    employee = return_valid_employee()

    assert_equal(0, employee.children.size)
    assert_equal(0, employee.children_under_6)
    assert_equal(0, employee.children_under_19)

    child = Child.new
    child.first_name = "Older"
    child.last_name = "Child"
    child.birth_date = "2000-01-01"
    child.is_student = true
    employee.person.children << child

    assert_equal(1, employee.person.children.size)
    assert_equal(0, employee.children_under_6)
    assert_equal(1, employee.children_under_19)

    child = Child.new
    child.first_name = "Younger"
    child.last_name = "Child"
    child.birth_date = "2015-01-01"
    child.is_student = false
    employee.person.children << child

    assert_equal(2, employee.person.children.size)
    assert_equal(1, employee.children_under_6)
    assert_equal(2, employee.children_under_19)
  end

  def some_valid_params(params={})
    {first_name: 'Joe',
     last_name: 'Shmoe',
     title: 'Director',
     location: 'bro',
     department: @admin,
     hours_day: 12,
     supervisor: @yoda}.merge params
  end
end
