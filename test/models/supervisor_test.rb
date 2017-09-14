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
end
