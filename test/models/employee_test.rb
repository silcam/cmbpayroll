require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  def setup
    @luke = employees :Luke
  end

  test "validations" do
    params = {first_name: 'Joe', last_name: 'Shmoe'}
    model_validation_hack_test Employee, params
  end

  # test "relations" do
  #   lukes_coke = transactions :LukesCoke
  #   assert_includes @luke.transactions, lukes_coke
  # end

  test "Full Name" do
    assert_equal "Luke Skywalker", @luke.full_name
  end

  test "Full Name Rev" do
    assert_equal "Skywalker, Luke", @luke.full_name_rev
  end
end