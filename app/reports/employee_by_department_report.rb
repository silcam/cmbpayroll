class EmployeeByDepartmentReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.first_name, ' ', p.last_name) as employee_name,
  e.id as emp_number,
  d.name as department,
  e.title as job_description,
  to_char(e.contract_start, 'DD/MM/YYYY') as beginning_contract,
  to_char(e.contract_end, 'DD/MM/YYYY') as ending_contract,
  w.basewage as base_wage,
  e.employment_status as per,
  CONCAT(e.category, '-', e.echelon) as cat_ech,
  e.last_raise_date as last_raise,
  e.marital_status as m_c,
  c.numchildren as children,
  p.gender
FROM
  employees e
    INNER JOIN people p ON
      e.person_id = p.id
    LEFT OUTER JOIN wages w ON
      w.category = e.category AND
      w.echelonalt = e.echelon
    LEFT OUTER JOIN departments d ON
      e.department_id = d.id
    LEFT OUTER JOIN
      (SELECT
        parent_id,
        count(*) as numchildren
      FROM
        children
      GROUP BY
        parent_id
      ) c ON p.id = c.parent_id
    SELECTSTATEMENT
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

end
