require "test_helper"

class PersonTest < ActiveSupport::TestCase

  def setup
    @luke = people :Luke
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
