require "test_helper"

class BelongsToPersonTest < ActiveSupport::TestCase
  # Use Child as a test case since it includes BelongsToPerson

  def setup
    @lukejr = people :LukeJr
    @lukejr_child = children :LukeJr
  end

  test "Belongs To" do
    assert_equal @lukejr, @lukejr_child.person

    # Autosave
    @lukejr_child.first_name = 'Luke!'
    @lukejr_child.save
    @lukejr.reload
    assert_equal 'Luke!', @lukejr.first_name

    # Validation
    @lukejr_child.person.first_name = ''
    refute @lukejr_child.valid?, "Should not be valid if assoc. Person isn't"
  end

  test "Access to Person methods" do
    assert_equal 'Luke Jr.', @lukejr.first_name
    @lukejr_child.update(first_name: 'Luke!!')
    @lukejr.reload
    assert_equal 'Luke!!', @lukejr.first_name
  end

  test "New with Person" do
    # assert_raises (NoMethodError){ Child.new.first_name = "Bill" }
    # assert_nil Child.new.person
    assert Child.new_with_person.first_name = "Bill"
  end

  test "New" do
    assert Child.new.first_name = 'Bill'
    assert Child.create!(first_name: 'F', last_name: 'L', parent: people(:Luke))
  end
end