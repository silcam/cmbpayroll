class EmployeeByDepartmentReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
CONCAT(people.first_name, ' ', people.last_name) as employee_name,
'123' as emp_number,
departments.name as department,
employees.title as job_description,
to_char(employees.contract_start, 'DD/MM/YYYY') as beginning_contract,
to_char(employees.contract_end, 'DD/MM/YYYY') as ending_contract,
employees.id as base_wage,
employees.employment_status as per,
CONCAT(employees.category, ' ', employees.echelon) as cat_ech,
employees.last_raise_date as last_raise,
employees.marital_status as m_c,
employees.id as children,
people.gender
    SELECTSTATEMENT

    Employee.unscoped().select(select).joins(:person).left_outer_joins(:department).order("departments.name asc").all().to_sql
  end

  def formatted_title
    I18n::t(:Employee_report_by_dept, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      children: 'No. Child',
      emp_number: 'Emp No',
      m_c: 'M/C',
      cat_ech: 'Cat / Ech.'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  def format_children(value)
    Employee.find(value).children.size
  end

  def format_base_wage(value)
    formatter.number_to_currency(Employee.find(value).find_wage, locale: :cm, unit: '')
  end

  def format_gender(value)
    fixup_enum(value, Person.genders, :genders)
  end

  def format_m_c(value)
    fixup_enum(value, Employee.marital_statuses, :marital_statuses)
  end

  def format_per(value)
    fixup_enum(value, Employee.employment_statuses, :employment_statuses)
  end

end
