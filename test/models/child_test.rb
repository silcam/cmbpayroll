require "test_helper"


class ChildTest < ActiveSupport::TestCase

#describe Child do
#  let(:child) { Child.new }
#
#  @child.first_nane = 'Test First Name'
#  child.last_name = 'Test Last Name'
#  child.birth_date = '2014-01-01'
#  child.is_student = true
#  child.employee_id = 8
#
#  it "must be valid" do
#    value(child).must_be :valid?
#  end
#end

  test "child is has association" do
    t = Child.reflect_on_association(:employee).macro == :belongs_to
  end

  test "child is valid" do

    # reduce redundancy here
    employee = Employee.new

    employee.first_name = "Bob"
    employee.last_name = "BobLastName"
    employee.title = "Assistant Assistant"
    employee.department = "Dept of Redundancy Dept"
    employee.hours_day = 18

    employee.save

    assert_not_nil(employee.id, "Employee should have id now")

    params = {
        first_name: 'Child',
        last_name: 'Name',
        birth_date: '2008-01-01T01:01:01+01:00',
        is_student: true,
        employee_id: employee.id
    }

    model_validation_hack_test Child, params
  end

end
