require 'test_helper'

class MockEmployeeServiceTest < ActiveSupport::TestCase

  def setup
    super
    @luke = employees :Luke
    @anakin = employees :Anakin
    @chewie = employees :Chewie
  end

  test "All in Order" do
    order_test [:first_name], [@anakin, @chewie, @luke]
    order_test [[:first_name, :asc]], [@anakin, @chewie, @luke]
    order_test [:first_name, :last_name], [@anakin, @chewie, @luke]
    order_test [[:first_name, :desc]], [@luke, @chewie, @anakin]
    order_test [:last_name, :first_name], [@anakin, @luke, @chewie]
    order_test [:last_name, [:first_name, :desc]], [@luke, @anakin, @chewie]
  end

  def order_test(order, expected)

    result = Employee.all(order: order)

    expected.each_index do |i|
      next if i == 0
      assert result.index(expected[i]) > result.index(expected[i-1]),
             "Order: #{order} - #{expected[i-1].first_name} should come before #{expected[i].first_name}"
    end
  end
end
