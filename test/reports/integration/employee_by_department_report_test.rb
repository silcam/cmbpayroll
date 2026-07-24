require "test_helper"

class EmployeeByDepartmentReportTest < ActiveSupport::TestCase

  test "a period with no processed payslips returns no rows without erroring" do
    rows = run_employee_by_department_report("2018-1")
    assert_equal([], rows, "no payslips were processed in this period")
  end

  test "a processed payslip appears in the report for its own period, with fields matching the employee record" do
    employee = return_valid_employee
    employee.gender = "male"
    employee.save!

    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    row = find_employee_row(run_employee_by_department_report("2018-7"), employee)

    assert(row, "the employee's july payslip should show up in july's report")
    assert_equal("#{employee.last_name}, #{employee.first_name}", row["employee_name"])
    assert_equal(employee.department.name, row["department"])
    assert_equal(employee.title, row["job_description"])
    assert_equal(employee.contract_start.strftime("%d/%m/%Y"), row["beginning_contract"])
    assert_nil(row["ending_contract"])
    assert_equal(employee.wage, row["base_wage"].to_i)

    # per/m_c/gender all happen to compare against enum value 0 here
    # (full_time/single/male) -- refute_nil first so a NULL column can't
    # silently pass as a false "0".
    refute_nil(row["per"])
    assert_equal(Employee.employment_statuses[employee.employment_status], row["per"].to_i)
    assert_equal("#{Employee.categories[employee.category]}-#{Employee.echelons[employee.echelon]}", row["cat_ech"])
    refute_nil(row["m_c"])
    assert_equal(Employee.marital_statuses[employee.marital_status], row["m_c"].to_i)
    refute_nil(row["gender"])
    assert_equal(Person.genders[employee.gender], row["gender"].to_i)
    assert_nil(row["children"], "no children on record")
    assert_nil(row["last_raise"], "no raises on record")
  end

  test "children count reflects the number of children on record" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    Child.new(parent: employee.person, first_name: "Kid", last_name: "One",
        birth_date: Date.new(2015, 1, 1)).save!
    Child.new(parent: employee.person, first_name: "Kid", last_name: "Two",
        birth_date: Date.new(2017, 1, 1)).save!

    row = find_employee_row(run_employee_by_department_report("2018-7"), employee)
    assert_equal(2, row["children"].to_i)
  end

  test "category/echelon, base_wage and last_raise reflect the employee's CURRENT grade, not the already-processed period's snapshot (see FIXME)" do
    employee = return_valid_employee
    july = Period.new(2018, 7)
    generate_work_hours(employee, july)
    Payslip.process(employee, july)

    original_cat_ech = "#{Employee.categories[employee.category]}-#{Employee.echelons[employee.echelon]}"
    original_wage = employee.wage

    # Grant a raise the same way RaisesController#create does: a Raise
    # record plus an immediate, synchronous mutation of the employee's own
    # grade -- there's no effective-dated ledger (see
    # PLAN_raise_effective_date.md), so this takes hold right away.
    raise_date = Date.new(2018, 8, 1)
    grant_raise(employee, date: raise_date, echelon: "a")

    row = find_employee_row(run_employee_by_department_report("2018-7"), employee)

    refute_equal(original_cat_ech, row["cat_ech"],
        "documents the FIXME: july's report drifts to the employee's current grade, not july's own")
    assert_equal("#{Employee.categories[employee.category]}-#{Employee.echelons[employee.echelon]}", row["cat_ech"])
    refute_equal(original_wage, row["base_wage"].to_i,
        "base_wage is derived from the current category/echelon, so it drifts too")
    assert_equal(raise_date.strftime("%d/%m/%Y"), row["last_raise"],
        "last_raise is simply the most recent raise on record, not scoped to the report's period either")
  end

  private

  def run_employee_by_department_report(period_str)
    run_report(EmployeeByDepartmentReport, period_str)
  end

  def find_employee_row(rows, employee)
    rows.find { |row| row["emp_number"].to_i == employee.id }
  end

  # Mirrors RaisesController#create: a Raise record capturing the new
  # grade, plus an immediate mutation of the employee itself.
  def grant_raise(employee, date:, category: nil, echelon: nil, wage_scale: nil, wage: nil)
    # Raise.new unconditionally stamps date = Date.today after construction,
    # overriding any date: passed to .new -- so it has to be set afterward.
    raise_record = employee.raises.new
    raise_record.date = date
    raise_record.category = category || employee.category
    raise_record.echelon = echelon || employee.echelon
    raise_record.wage_scale = wage_scale || employee.wage_scale
    raise_record.wage_period = employee.wage_period
    raise_record.wage = wage || employee.wage
    raise_record.save!

    employee.category = category if category
    employee.echelon = echelon if echelon
    employee.wage_scale = wage_scale if wage_scale
    employee.wage = wage if wage
    employee.save!

    raise_record
  end

end
