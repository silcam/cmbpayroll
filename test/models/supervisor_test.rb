require "test_helper"

class SupervisorTest < ActiveSupport::TestCase

  def setup
    @yoda = supervisors :Yoda
  end

  test "Validation" do
    model_validation_hack_test Supervisor, {first_name: 'F', last_name: 'L'}
  end

  test "Associations" do
    luke = employees :Luke
    assert_includes @yoda.employees, luke
  end

  test "Cannot destroy supervisor with employees" do
    assert_raises (ActiveRecord::DeleteRestrictionError){ @yoda.destroy }
  end

  test "Can destroy sup without employees" do
    emperor = supervisors :Emperor
    @yoda.employees.each{ |e| e.update(supervisor: emperor) }
    @yoda.reload
    assert @yoda.destroy
  end
end
