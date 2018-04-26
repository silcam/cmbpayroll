class TransactionReport < CMBReport

  SELECTSTMT = <<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ' ', p.first_name) as employee_name,
  e.id,
  allitems.type,
  allitems.date,
  allitems.note,
  allitems.amount,
  allitems.unit,
  d.name as dept_name,
  d.id as dept_id
FROM
  people p, employees e
  LEFT JOIN payslips ps ON ps.employee_id = e.id
  LEFT OUTER JOIN (
      SELECT payslip_id, 'D' as type, note, amount, 'CFA' as unit, date
      FROM deductions
      WHERE upper(note) NOT IN ('AMICAL','UNION')
    UNION ALL
      SELECT
        payslip_id, 'H' as type, 'Overtime Hours' as description,
        SUM(hours) as hours, 'Hours' as unit, MAX(created_at)
      FROM earnings
      WHERE
        upper(description) like 'OT%HOURS' AND
        hours > 0 AND
        payslip_id is not null
      GROUP BY payslip_id
    UNION ALL
      SELECT payslip_id, 'E' as type, description, amount, 'CFA' as unit, created_at
      FROM earnings
      WHERE
        is_bonus = 'f' AND
        upper(description) NOT IN ('MONTHLY WAGES','TRANSPORT','AMICAL') AND
        upper(description) NOT LIKE 'OT%' AND
        amount > 0
    UNION ALL
      SELECT ps.id, 'L' as type, 'New Loan', l.amount, 'CFA' as unit, l.origination
      FROM loans l, employees emp, payslips ps
      WHERE
        l.employee_id = emp.id AND
        emp.id = ps.employee_id AND
        ps.period_year = :year AND
        ps.period_month = :month AND
        l.origination >= :start AND
        l.origination <= :finish
    ) as allitems
    ON allitems.payslip_id = ps.id
  LEFT JOIN departments d ON e.department_id = d.id
WHERE
  e.person_id = p.id AND
  e.employment_status IN :employment_status AND
  allitems.note is not null AND
  ps.period_year = :year AND
  ps.period_month = :month
    SELECTSTATEMENT


  def format_header(column_name)
    custom_headers = {
      children: 'Child',
      m_c: 'Mar',
      cat_ech: 'Cat/Ech'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  def format_date(value)
    date = DateTime.strptime(value, '%Y-%m-%d %H:%M:%S')
    date.strftime('%Y-%m-%d')
  end

end
