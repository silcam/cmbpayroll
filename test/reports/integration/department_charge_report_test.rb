require "test_helper"

class DepartmentChargeReportTest < ActiveSupport::TestCase

  test "Test that Becoming Inactive in Later Period Doesn't change earlier Report" do
    employee = employees :Luke
    dec19 = Period.new(2019,12)
    generate_work_hours(employee, dec19)

    # Get paid in Period 1
    payslip = Payslip.process(employee, dec19)
    assert(payslip.salaire_net > 0)

    # Verify in report in period 1
    r = run_query("DepartmentChargeReport", dec19)
    find_luke_with_pay(r, employee)

    # Advance to period 2
    jan20 = Period.new(2020,1)
    generate_work_hours(employee, jan20)
    # become inactive
    employee.employment_status = "inactive"
    # run payroll
    payslip = Payslip.process(employee, jan20)
    refute(payslip, "Should not get a payslip in jan20")

    # Verify not in report in period 2
    r = run_query("DepartmentChargeReport", jan20)
    do_not_find_luke(r, employee)

    # Verify in report in period 1 still
    r = run_query("DepartmentChargeReport", dec19)
    find_luke_with_pay(r, employee)
  end

  test "Test Going on Leave Still Leaves employee In Report With Zero pay" do
    employee = employees :Luke
    dec19 = Period.new(2019,12)
    generate_work_hours(employee, dec19)

    # Get paid in Period 1
    payslip = Payslip.process(employee, dec19)
    assert(payslip.salaire_net > 0)

    # Verify in report in period 1
    r = run_query("DepartmentChargeReport", dec19)
    find_luke_with_pay(r, employee)

    # Advance to period 2
    jan20 = Period.new(2020,1)
    generate_work_hours(employee, jan20)
    employee.employment_status = "leave"

    # run payroll
    payslip = Payslip.process(employee, jan20)
    assert(payslip, "Should get a payslip in jan20")
    assert_equal(0, payslip.salaire_net, "should get 0 pay since on leave")

    # Verify in report in period 2
    r = run_query("DepartmentChargeReport", jan20)
    find_luke_with_no_pay(r, employee)

    # Verify in report in period 1 still
    r = run_query("DepartmentChargeReport", dec19)
    find_luke_with_pay(r, employee)
  end

  def run_query(class_obj, period)
    report = Object.const_get(class_obj).new(period: period)
    report.options[:period] = period.to_s
    sql = report.sql

    # This is dumb, but the report always runs out of the development database.
    sql = sql.gsub(":month",period.month.to_s)
    sql = sql.gsub(":year",period.year.to_s)
    r = ActiveRecord::Base.connection.execute(sql)
  end

  def find_luke_with_pay(results, employee)
    search_for_luke(results, employee, true, true)
  end

  def find_luke_with_no_pay(results, employee)
    search_for_luke(results, employee, true, false)
  end

  def do_not_find_luke(results, employee)
    search_for_luke(results, employee, false, false)
  end

  def search_for_luke(results, employee, find, with_pay)
    found_luke = false
    luke_charge = -1
    results.each do |h|
      if (h["employee_num"] == employee.id)
        found_luke = true
        luke_charge = h["dept_charge"]
      end
    end

    if (find)
      assert(found_luke, "should find luke in report")

      if (with_pay)
        assert(luke_charge > 0, "luke should have charge")
      else
        assert_equal(0, luke_charge, "should not have charge if on leave")
      end
    else
      refute(found_luke, "should not find luke in report")
    end

  end

end
