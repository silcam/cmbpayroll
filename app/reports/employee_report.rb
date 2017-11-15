class EmployeeReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
CONCAT(people.first_name, ' ', people.last_name) as employee_name,
employees.id as emp_number,
departments.name as department,
employees.title as job_description,
to_char(employees.contract_start, 'DD/MM/YYYY') as beginning_contract,
to_char(employees.contract_end, 'DD/MM/YYYY') as ending_contract,
employees.id as base_wage,
employees.employment_status as per,
CONCAT(employees.category, '-', employees.echelon) as cat_ech,
employees.last_raise_date as last_raise,
employees.marital_status as m_c,
employees.id as children,
people.gender
    SELECTSTATEMENT

    Employee.select(select).joins(:person).left_outer_joins(:department).all().to_sql
  end

  def formatted_title
    I18n::t(:Employee_report, scope: [:reports])
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

end
