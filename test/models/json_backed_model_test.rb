require 'test_helper'

class JSONBackedModelTest < ActiveSupport::TestCase

  # Test the methods of JSONBackedModel using the Employee subclass

  def setup
    super
   @luke = employees :Luke
  end

  test "Luke's attributes" do
    expected = {id: 1, first_name: 'Luke', last_name: 'Skywalker'}
    assert_equal expected, @luke.attributes
  end

  test "Update Luke's Attributes" do
    @luke.attributes = {first_name: 'Babe', last_name: 'Ruth'}
    assert_equal 'Babe', @luke.first_name
    assert_equal 'Ruth', @luke.last_name
  end

  test "Save Luke" do
    @luke.first_name = 'Gary'
    @luke.save
    @luke = employees :Luke
    assert_equal 'Gary', @luke.first_name
  end

  test "Save a new employee" do
    han = Employee.new(first_name: 'Han', last_name: 'Solo')
    han.save
    refute_nil han.id
    assert_includes Employee.all, han
  end

  test "New Record" do
    han = Employee.new(first_name: 'Han', last_name: 'Solo')
    assert han.new_record?, "Han should be a new record"
    refute @luke.new_record?, "Luke should not be a new record"
    han.save
    refute han.new_record?, "Han should not longer be a new record"
  end

  test "Employee Attributes" do
    expected = [:id, :first_name, :last_name]
    assert_equal expected, Employee.attributes
  end

  test "All Employees" do
    assert_includes Employee.all, @luke
  end

  test "Find Luke" do
    assert_equal @luke, Employee.find(@luke.id)
  end

end