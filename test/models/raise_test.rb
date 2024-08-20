require "test_helper"

class RaiseTest < ActiveSupport::TestCase

  test "Exceptional can be read/set" do
    employee = return_valid_employee()
    raise = Raise.new_for(employee)
    refute(raise.is_exceptional, "not exceptional by default")

    raise.is_exceptional = true
    raise.save
    assert(raise.is_exceptional, "but can be exceptional")    
  end
  
end