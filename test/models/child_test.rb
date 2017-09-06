require "test_helper"


class ChildTest < ActiveSupport::TestCase

  def setup
    @luke = employees :Luke
  end


  test "child is has association" do
    t = Child.reflect_on_association(:employee).macro == :belongs_to
  end

  test "child is valid" do
    params = {
        first_name: 'Child',
        last_name: 'Name',
        birth_date: '2008-01-01T01:01:01+01:00',
        employee_id: @luke.id
    }

    model_validation_hack_test Child, params
  end

  test "Should validate if child is not a student" do
    assert @luke.children.create!(first_name: 'F',
                                        last_name: 'L',
                                        birth_date: Date.new(2017, 7, 4),
                                        is_student: false)
    refute @luke.children.last.is_student
  end

end
