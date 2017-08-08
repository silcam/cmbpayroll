require 'test_helper'

class BelongsToJSONBackedModelTest < ActiveSupport::TestCase

  # Test the methods of BelongsToJSONBackedModel Module using the
  # Transaction model which uses it

  def setup
    super
    @lukes_coke = transactions :LukesCoke
    @luke = employees :Luke
  end

  test "Get Owner" do
    assert_equal @luke, @lukes_coke.employee
  end

  test "Set Owner" do
    lukes_beer = Transaction.new(amount: 700)
    lukes_beer.employee = @luke
    assert_equal @luke.id, lukes_beer.employee_id
  end
end