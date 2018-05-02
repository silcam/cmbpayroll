class EmployeeDeductionReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ' ', p.first_name) as Employee_Name,
  e.id,
  ps.gross_pay,
  SUM(dsa.amount) as Salary_Advance,
  ps.total_tax,
  SUM(dun.amount) as Union,
  SUM(dlo.amount) as Loan_Payment,
  SUM(dph.amount) as Photocopies,
  SUM(dte.amount) as Telephone,
  SUM(dwa.amount) as Utilities,
  SUM(dad.amount) as AMICAL,
  SUM(dot.amount) as Other,
  ps.net_pay
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
    (SELECT payslip_id, note, amount FROM deductions WHERE note = '#{Charge::ADVANCE}' OR note = '#{Payslip::LOCATION_TRANSFER}') dsa
    ON dsa.payslip_id = ps.id
WHERE
  e.employment_status IN :employment_status AND
  e.person_id = p.id AND
  e.id = ps.employee_id AND
  ps.period_year = :year AND
  ps.period_month = :month
GROUP BY
  ps.id,
  p.first_name,
  p.last_name,
  e.id,
  ps.gross_pay,
  ps.total_tax,
  ps.net_pay
ORDER BY
  p.last_name ASC;
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Employee_deduction_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      taxable: 'Gross Wage',
      net_pay: 'Cash Pay'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

end
