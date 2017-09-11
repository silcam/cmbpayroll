require "test_helper"


class ChildTest < ActiveSupport::TestCase

  def setup
    @luke = people :Luke
    @lukejr = people :LukeJr
  end


  test "child is has association" do
    t = Child.reflect_on_association(:parent).macro == :belongs_to

    assert_equal @lukejr, @lukejr.child.person
    assert_equal @luke, @lukejr.child.parent
  end

  test "child is valid" do
    params = {
        person: Person.new(first_name: 'Billy',
                           last_name: 'Bob'),
        parent: @luke
    }

    model_validation_hack_test Child, params
  end

  test "Should validate if child is not a student" do
    assert @luke.children.create!(person: Person.new(first_name: 'F',
                                        last_name: 'L',
                                        birth_date: Date.new(2017, 7, 4)),
                                        is_student: false)
    refute @luke.children.last.is_student
  end

end
