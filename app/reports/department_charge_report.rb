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
  ps.salaire_net as net_pay,
  b.add_pay,
  ps.taxable + b.add_pay as adj_wage,
  ps.department_cnps,
  ps.department_credit_foncier as credit_foncier,
  ps.cnpswage + ps.department_credit_foncier as dept_taxes,
  ps.department_severance as dept_severance,
  ps.vacation_earned as vacation_days,
  CEILING(ps.vacation_pay_earned * c.department_charge_percent) as vacation_pay,
  ps.employee_fund,
  ps.employee_contribution,
  COALESCE(ps.taxable,0) +
      COALESCE(b.add_pay,0) +
      COALESCE(ps.department_cnps,0) +
      COALESCE(ps.department_credit_foncier,0) +
      COALESCE(CEILING(
          ps.vacation_pay_earned * c.department_charge_percent
      ),0) +
      COALESCE(ps.employee_fund,0) +
      COALESCE(ps.employee_contribution,0) as total_charge,
  wlp.percentage as dept_percentage,
  floor((COALESCE(ps.taxable,0) +
      COALESCE(b.add_pay,0) +
      COALESCE(ps.department_cnps,0) +
      COALESCE(ps.department_credit_foncier,0) +
      COALESCE(CEILING(
          ps.vacation_pay_earned * c.department_charge_percent
      ),0) +
      COALESCE(ps.employee_fund,0) +
      COALESCE(ps.employee_contribution,0)) * wlp.percentage) as dept_charge,
  ps.period_suppl_days
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
      SELECT id, (trunc((salaire_net + 4) / 5 ) * 5) - salaire_net as add_pay from payslips) b ON
        ps.id = b.id
    INNER JOIN work_loan_percentages wlp ON ps.id = wlp.payslip_id
    INNER JOIN departments d ON wlp.department_id = d.id
    INNER JOIN departments ed ON e.department_id = ed.id,
    (
      SELECT #{SystemVariable.value(:dept_charge_percent)} as department_charge_percent
    ) c
WHERE
  ps.period_year = :year AND
  ps.period_month = :month
ORDER BY
  department_id, employee_name ASC
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
