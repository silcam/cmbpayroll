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

  test "under 6" do
    person = Person.new(first_name: 'Responsible',
        last_name: 'Parent')
    person.save

    assert_equal(0, Child.under_6.count())

    child = Child.new
    child.first_name = "Under"
    child.last_name = "Six"

    # Exactly 6 years ago isn't "under 6"
    child.birth_date = 6.years.ago
    person.children << child

    assert_equal(0, Child.under_6.count())

    # Exactly 6 years ago less 1 day is "under 6"
    child.birth_date = 6.years.ago + 1.day
    child.save

    assert_equal(1, Child.under_6.count())
  end

  test "under 19" do
    person = Person.new(first_name: 'Responsible',
        last_name: 'Parent')
    person.save

    assert_equal(0, Child.under_19.count())

    child = Child.new
    child.first_name = "Under"
    child.last_name = "19"

    # Exactly 19 years ago isn't "under 19"
    child.birth_date = 19.years.ago
    person.children << child

    assert_equal(0, Child.under_19.count())

    # Exactly 19 years ago less 1 day is "under 19"
    child.birth_date = 19.years.ago + 1.day
    child.save

    assert_equal(1, Child.under_19.count())
  end
end
