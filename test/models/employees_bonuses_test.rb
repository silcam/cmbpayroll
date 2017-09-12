require "test_helper"

class EmployeesBonusesTest < ActiveSupport::TestCase

  def test_valid_association_bonus_side

    bonus = Bonus.new
    bonus.name = "Bonus 1"
    bonus.quantity = 20.2
    bonus.bonus_type = "percentage"

    assert bonus.valid?

    employee = return_valid_employee()

    assert employee.valid?

    bonus.employees << employee
    bonus.save

    assert_equal(1, bonus.employees.size)
    assert_equal(1, employee.bonuses.size)


    bonus2 = Bonus.new
    bonus2.name = "Bonus 2"
    bonus2.quantity = 18947
    bonus2.bonus_type = "fixed"

    assert bonus2.valid?

    bonus2.employees << employee
    bonus2.save

    assert_equal(1, bonus2.employees.size)
    assert_equal(2, employee.bonuses.size)

  end

  def test_valid_association_employee_side

    bonus = Bonus.new
    bonus.name = "Bonus 1"
    bonus.quantity = 20.2
    bonus.bonus_type = "percentage"

    assert bonus.valid?

    employee = return_valid_employee()

    assert employee.valid?

    employee.bonuses << bonus
    employee.save

    assert_equal(1, employee.bonuses.size)
    assert_equal(1, bonus.employees.size)

    bonus2 = Bonus.new
    bonus2.name = "Bonus 2"
    bonus2.quantity = 18947
    bonus2.bonus_type = "fixed"

    assert bonus2.valid?

    employee.bonuses << bonus2
    employee.save

    assert_equal(2, employee.bonuses.size)
    assert_equal(1, bonus2.employees.size)

  end


  def test_assignment_to_employee

    # create 2 valid bonuses
    bonus = Bonus.new
    bonus.name = "Bonus 1"
    bonus.quantity = 20.2
    bonus.bonus_type = "percentage"
    assert bonus.valid?
    bonus.save
    assert(bonus.id)

    bonus2 = Bonus.new
    bonus2.name = "Bonus 2"
    bonus2.quantity = 18947
    bonus2.bonus_type = "fixed"
    assert bonus2.valid?
    bonus2.save
    assert(bonus2.id)

    # employee to be assigned
    employee = return_valid_employee()
    assert(employee.valid?)
    assert(employee.id)

    # assign to employee via method
    bonus_hash = { bonus.id => "1", bonus2.id => "0" }

    Bonus.assign_to_employee(employee, bonus_hash)

    assert_equal(1, employee.bonuses.size)
    assert(employee.bonuses.exists?(bonus.id))
    refute(employee.bonuses.exists?(bonus2.id))

    # assign the other bonus
    bonus_hash = { bonus.id => "0", bonus2.id => "1" }

    Bonus.assign_to_employee(employee, bonus_hash)

    assert_equal(1, employee.bonuses.size)
    refute(employee.bonuses.exists?(bonus.id))
    assert(employee.bonuses.exists?(bonus2.id))

    # assign the both
    bonus_hash = { bonus.id => "1", bonus2.id => "1" }

    Bonus.assign_to_employee(employee, bonus_hash)

    assert_equal(2, employee.bonuses.size)
    assert(employee.bonuses.exists?(bonus.id))
    assert(employee.bonuses.exists?(bonus2.id))

    # assign none
    bonus_hash = { bonus.id => "0", bonus2.id => "0" }

    Bonus.assign_to_employee(employee, bonus_hash)

    assert_equal(0, employee.bonuses.size)
    refute(employee.bonuses.exists?(bonus.id))
    refute(employee.bonuses.exists?(bonus2.id))

  end
end
