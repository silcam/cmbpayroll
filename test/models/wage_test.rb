require "test_helper"

class WageTest < ActiveSupport::TestCase

  test "Should not be able to create a new wage object" do
    wage = Wage.new

    wage.category = 4
    wage.echelon = "g"
    wage.echelonalt = 13
    wage.basewage = 13
    wage.basewageb = 13
    wage.basewagec = 13
    wage.basewaged = 13
    wage.basewagee = 13

    assert(wage.valid?, "should be valid and ready to be saved")

    assert_raise(ActiveRecord::ReadOnlyRecord, "Should not be allowed to save") do
      wage.save
    end
  end

  test "Should be able to edit a new wage object" do
    wage = Wage.find_by(category: 1, echelon: 'a', echelonalt: 1)

    wage.basewageb = 13000

    assert(wage.valid?, "should be valid and ready to be saved")

    assert_nothing_raised do
      wage.save
    end
  end

  test "Should not be able to delete a wage object" do
    wage = Wage.find_by(category: 1, echelon: 'a', echelonalt: 1)

    wage.basewageb = 13000

    assert(wage.valid?, "should be valid and ready to be saved")

    assert_raise(ActiveRecord::ReadOnlyRecord, "Should not be allowed to delete") do
      wage.destroy
    end
  end

  test "Can lookup wage information" do
    echelon, echelonalt = Wage.echelon_find("b")
    assert_equal("b", echelon)
    assert_equal(2, echelonalt)

    echelon, echelonalt = Wage.echelon_find("one")
    assert_equal("a", echelon)
    assert_equal(1, echelonalt)

    echelon, echelonalt = Wage.echelon_find("six")
    assert_equal("f", echelon)
    assert_equal(6, echelonalt)

    echelon, echelonalt = Wage.echelon_find("eleven")
    assert_equal("-", echelon)
    assert_equal(11, echelonalt)

    echelon, echelonalt = Wage.echelon_find("thirteen")
    assert_equal("-", echelon)
    assert_equal(13, echelonalt)

    echelon, echelonalt = Wage.echelon_find("d")
    assert_equal("d", echelon)
    assert_equal(4, echelonalt)
  end

  test "Can return wage with wagescale c and d" do
    # This should not throw an exception, i.e. return a valid object
    # this is exhibiting a case where the site would throw an
    # exception if these options were entered.
    emp = return_valid_employee

    emp.category_eight!
    emp.echelon_a!
    emp.wage_scale_d!

    assert(emp.wage)
  end

  test "Can retrieve record" do
    wage = Wage.find_by(category: 1, echelon: 'd', echelonalt: 4)

    refute_nil(wage)

    assert_equal(42010, wage.basewage)
    assert_equal(26445, wage.basewageb)
    assert_equal(0, wage.basewagec)

  end

  test "Can retrieve using employee enum values" do
    wage = Wage.find_wage("one", "d", "a")
    refute_nil(wage)
    assert_equal(42010, wage)

    wage = Wage.find_wage("two", "six", "a")
    refute_nil(wage)
    assert_equal(59320, wage)

    wage = Wage.find_wage("two", "six", "b")
    refute_nil(wage)
    assert_equal(34020, wage)
  end

end
