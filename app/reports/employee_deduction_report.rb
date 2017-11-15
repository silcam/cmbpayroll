class EmployeeDeductionReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.first_name, ' ', p.last_name) as Employee_Name,
  e.id,
  ps.gross_pay,
  dsa.amount as Salary_Advance,
  ps.total_tax,
  dun.amount as Union,
  ps.net_pay,
  dlo.amount as Loan_Payment,
  dph.amount as Photocopies,
  dte.amount as Telephone,
  dwa.amount as Utilities,
  dad.amount as AMICAL,
  dot.amount as Other
FROM
  people p,
  employees e,
  payslips ps
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'Loan Payment') dlo
    ON dlo.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'AMICAL' OR note = 'amical') dad
    ON dad.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'Water') dwa
    ON dwa.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'Other') dot
    ON dot.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'Union' OR note = 'union') dun
    ON dun.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'Photocopies') dph
    ON dph.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'Telephone') dte
    ON dte.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, note, amount FROM deductions WHERE note = 'Salary Advance') dsa
    ON dsa.payslip_id = ps.id
WHERE
  e.person_id = p.id AND
  e.id = ps.employee_id AND
  ps.period_year = :year AND
  ps.period_month = :month
ORDER BY
  ps.id DESC;
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Employee_deduction_report, scope: [:reports])
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

  def year
    period = options[:period]
    year, month = period.split('-')
    year
  end

  def month
    period = options[:period]
    year, month = period.split('-')
    month
  end

  def format_gross_pay(value)
    cfa(value)
  end

  def format_salary_advance(value)
    cfa(value)
  end

  def format_total_tax(value)
    cfa(value)
  end

  def format_union(value)
    cfa(value)
  end

  def format_net_pay(value)
    cfa(value)
  end

  def format_loan_payment(value)
    cfa(value)
  end

  def format_photocopies(value)
    cfa(value)
  end

  def format_telephone(value)
    cfa(value)
  end

  def format_utilities(value)
    cfa(value)
  end

  def format_amical(value)
    cfa(value)
  end

  def format_other(value)
    cfa(value)
  end

end
