require "test_helper"

class PersonTest < ActiveSupport::TestCase

  def setup
    @luke = people :Luke
    @leia = people :Leia
    @lukejr = people :LukeJr
  end

  test "Associations" do
    assert_equal employees(:Luke), @luke.employee
    assert_equal users(:Luke), @luke.user
    assert_equal children(:LukeJr), @lukejr.child
    assert_includes @luke.children, @lukejr.child
  end

  test "Presence Validations" do
    model_validation_hack_test(Person, some_valid_params)
  end

  test "Valid Gender" do
    # Accept nil, 0 or 1
    joe = Person.create!(first_name: 'Joe', last_name: 'Schmoe')
    joe.gender = :male
    joe.save!
    assert_raises (ArgumentError){ joe.gender = :t_rex }
  end

  test "Full Name" do
    assert_equal 'Luke Skywalker', @luke.full_name
  end

  test "Full Name Rev" do
    assert_equal 'Skywalker, Luke', @luke.full_name_rev
  end

  test "Birth Date" do
    @luke.birth_date = Date.new(1995,2,1)
    assert_equal(Date.new(1995,2,1), @luke.birth_date)
  end

  test "age" do
    assert_raise(ArgumentError, "didn't raise argerror on nil") do
      @leia.age
    end

    @leia.birth_date = Date.new(1992,1,1)
    assert_equal(-2, @leia.age(Period.new(1990,1)), "will return negatives")

    @leia.birth_date = Date.new(1992,1,1)
    assert_equal(27, @leia.age(Period.new(2019,12)))

    @leia.birth_date = Date.new(1992,1,1)
    assert_equal(28, @leia.age(Period.new(2020,1)))
  end

  test "Non-supervisors list" do
    nonsups = Person.non_supervisors
    assert_includes nonsups, people(:Chewie)
    refute_includes nonsups, people(:Yoda)
    refute_includes nonsups, @lukejr
  end

  test "Non-users list" do
    nonusers = Person.non_users
    assert_includes nonusers, people(:Chewie)
    refute_includes nonusers, @luke
    refute_includes nonusers, @lukejr
  end

  def some_valid_params
    {first_name: 'Ferris', last_name: 'Bueller'}
  end
end
