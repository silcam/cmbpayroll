require "test_helper"

class SystemVariableTest < ActiveSupport::TestCase

  test "Default Vacation Days" do
    assert_nil SystemVariable.find_by(key: 'vacation_days')
    assert_equal 18, SystemVariable.value(:vacation_days)
  end

  test "Non-Default Vacation Days" do
    SystemVariable.create!(key: 'vacation_days', value: 364) # :)
    assert_equal 364, SystemVariable.value(:vacation_days)
  end
end
