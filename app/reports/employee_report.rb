class EmployeeReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ', ', p.first_name) as employee_name,
  e.id as emp_number,
  d.name as department,
  e.title as job_description,
  to_char(e.contract_start, 'DD/MM/YYYY') as beginning_contract,
  to_char(e.contract_end, 'DD/MM/YYYY') as ending_contract,
  CASE
    WHEN w.basewage = 0
      THEN e.wage
      ELSE w.basewage
      END AS base_wage,
  e.employment_status as per,
  CONCAT(e.category, '-', e.echelon) as cat_ech,
  to_char(e.last_raise_date, 'DD/MM/YYYY') as last_raise,
  e.marital_status as m_c,
  c.numchildren as children,
  p.gender
FROM
  employees e
    INNER JOIN people p ON
      e.person_id = p.id
    INNER JOIN category_lookup cl ON
      e.category = cl.emp_val
    INNER JOIN echelon_lookup el ON
      e.echelon = el.emp_val
    LEFT OUTER JOIN wages w ON
      cl.wages_val = w.category AND
      el.wages_val = w.echelonalt
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
WHERE
  e.employment_status IN :employment_status
ORDER BY
  employee_name ASC
    SELECTSTATEMENT
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
