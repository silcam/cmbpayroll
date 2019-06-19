class EmployeeDeductionReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ' ', p.first_name) as Employee_Name,
  e.id,
  ps.gross_pay,
  dsa.amount as Salary_Advance,
  dbt.amount as Bank_Transfer,
  dlt.amount as Loc_Transfer,
  ps.total_tax,
  ps.union_dues as Union,
  dlo.amount as Loan_Payment,
  dph.amount as Photocopies,
  dte.amount as Telephone,
  dwa.amount as Utilities,
  dad.amount as AMICAL,
  dot.amount as Other,
  ps.net_pay
FROM
  people p,
  employees e,
  payslips ps
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE note = 'Loan Payment' GROUP BY payslip_id) dlo
    ON dlo.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE note = 'AMICAL' OR note = 'amical' GROUP BY payslip_id) dad
    ON dad.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE note = 'Water' GROUP BY payslip_id) dwa
    ON dwa.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE note = 'Other' GROUP BY payslip_id) dot
    ON dot.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE note = 'Photocopies' GROUP BY payslip_id) dph
    ON dph.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE note = 'Telephone' GROUP BY payslip_id) dte
    ON dte.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE deduction_type = #{Charge.charge_types["advance"]} GROUP BY payslip_id) dsa
    ON dsa.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE deduction_type = #{Charge.charge_types["bank_transfer"]} GROUP BY payslip_id) dbt
    ON dbt.payslip_id = ps.id
  LEFT OUTER JOIN
    (SELECT payslip_id, SUM(amount) as amount FROM deductions WHERE deduction_type = #{Charge.charge_types["location_transfer"]} GROUP BY payslip_id) dlt
    ON dlt.payslip_id = ps.id
WHERE
  e.employment_status IN :employment_status AND
  e.person_id = p.id AND
  e.id = ps.employee_id AND
  ps.period_year = :year AND
  ps.period_month = :month
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
