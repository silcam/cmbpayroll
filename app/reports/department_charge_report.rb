class DepartmentChargeReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ' ', p.first_name) as employee_name,
  d.id as department_id,
  d.name as department_name,
  e.id as employee_num,
  ps.gross_pay,
  ps.total_tax,
  ps.net_pay as net_pay,
  b.add_pay,
  ps.taxable + b.add_pay as adj_wage,
  ps.department_cnps,
  ps.department_credit_foncier as credit_foncier,
  ps.cnpswage + ps.department_credit_foncier as dept_taxes,
  ps.department_severance as dept_severance,
  ps.vacation_earned as vacation_days,
  ps.vacation_pay_earned as vacation_pay,
  ps.employee_fund,
  ps.employee_contribution,
  ps.taxable +
      b.add_pay +
      ps.department_cnps +
      ps.department_credit_foncier +
      ps.vacation_pay_earned +
      ps.employee_fund +
      ps.employee_contribution as total_charge,
  wlp.percentage as dept_percentage,
  floor((ps.taxable +
      b.add_pay +
      ps.department_cnps +
      ps.department_credit_foncier +
      ps.vacation_pay_earned +
      ps.employee_fund +
      ps.employee_contribution) * wlp.percentage) as dept_charge
FROM
  employees e
    INNER JOIN people p ON e.person_id = p.id
    INNER JOIN payslips ps ON e.id = ps.employee_id
    INNER JOIN (
      -- this is dumb, it's trying to figure out how
      -- many CFA are required to reach the next
      -- divisible by 5 amount.  It does this from
      -- the net pay, but then adds it to the taxable
      -- wage.  Not sure why.
      SELECT id, (trunc((net_pay + 4) / 5 ) * 5) - net_pay as add_pay from payslips) b ON
        ps.id = b.id
    INNER JOIN work_loan_percentages wlp ON ps.id = wlp.payslip_id
    INNER JOIN departments d ON wlp.department_id = d.id
    INNER JOIN departments ed ON e.department_id = ed.id
WHERE
  e.employment_status in (0,1,2) AND
  ps.period_year = :year AND
  ps.period_month = :month
ORDER BY
  department_id, employee_name ASC;
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Department_charge_report, scope: [:reports])
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
