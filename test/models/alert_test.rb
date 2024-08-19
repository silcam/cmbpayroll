require "test_helper"

class AlertTest < ActiveSupport::TestCase
  def setup
   #@july = Period.new(2017, 7)
  end

  test "Contract Start and No Raise" do
    Date.stub :today, Date.new(2018, 5, 18) do
      employee = return_valid_employee

      last_raise = employee.last_raise.try(:date)
      refute(last_raise, "should not have a last raise")

      # Set to 12 months.
      employee.contract_start = '2017-05-18'
      alerts = Alert.get_for_employee(employee)
      assert_equal(0, alerts.length)
      
      # Set to 24 months.
      employee.contract_start = '2016-05-17'
      alerts = Alert.get_for_employee(employee)
      assert_equal(1, alerts.length)

      # Set to 24 months minus 1 day``.
      employee.contract_start = '2016-05-18'
      alerts = Alert.get_for_employee(employee)
      assert_equal(0, alerts.length)
    end
  end

  test "No raise since last raise" do
    Date.stub :today, Date.new(2018, 5, 18) do
      employee = return_valid_employee

      last_raise = employee.last_raise.try(:date)
      refute(last_raise, "should not have a last raise")

      # Set to 24 months, with no raise, will alert.
      employee.contract_start = '2016-05-17'
      alerts = Alert.get_for_employee(employee)
      assert_equal(1, alerts.length)

      # add a raise year ago, this will silence alert.

      # Raise to 4e
      raise = Raise.new_for(employee)
      raise.category_four!
      raise.echelon_e!
      raise.save

      last_raise = employee.last_raise.try(:date)
      assert_equal(Date.today, last_raise, "should have a last raise of today")
      assert_equal("four", raise.category, "should be 4")
      assert_equal("e", raise.echelon, "should be e")

      # alert is silenced because of raise.
      alerts = Alert.get_for_employee(employee)
      assert_equal(0, alerts.length)
    end 
  end

  test "Contract end warning at 4 months" do
    Date.stub :today, Date.new(2018, 5, 18) do
      employee = return_valid_employee

      last_raise = employee.last_raise.try(:date)
      refute(last_raise, "should not have a last raise")
      refute(employee.contract_end, "should not have a contract end")

      # Set to 24 months, with no raise, will alert.
      employee.contract_start = '2016-05-19'
      alerts = Alert.get_for_employee(employee)
      assert_equal(0, alerts.length)

      employee.contract_end = '2018-9-17'
      employee.save

      alerts = Alert.get_for_employee(employee)
      assert_equal(1, alerts.length)

      # move it past 4 months.
      employee.contract_end = '2018-12-15'
      employee.save

      alerts = Alert.get_for_employee(employee)
      assert_equal(0, alerts.length)
    end 
  end

end
