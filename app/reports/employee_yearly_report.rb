class EmployeeYearlyReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
    SELECT
  e.id as employee_id,
  e.cnps as matricule_cnps,
  CONCAT(MAX(p.first_name), ' ', MAX(p.last_name)) as employee_name,
  ps.period_year as py,
  ROUND(COALESCE(SUM(ps.salaire_net),0) + COALESCE(SUM(v.vacation_pay),0) - COALESCE(SUM(v.total_tax),0)) as salaire_net,
  COALESCE(SUM(ps.ccf),0) + COALESCE(SUM(v.ccf),0) as ccf_tax,
  COALESCE(SUM(ps.cnps),0) + COALESCE(SUM(v.cnps),0) as cnps_tax,
  COALESCE(SUM(ps.proportional),0) + COALESCE(SUM(v.proportional),0) as prop_tax,
  COALESCE(SUM(ps.crtv),0) + COALESCE(SUM(v.crtv),0) as crtv_tax,
  COALESCE(SUM(ps.communal),0) + COALESCE(SUM(v.communal),0) as comm_tax,
  COALESCE(SUM(ps.cac),0) + COALESCE(SUM(v.cac),0) as cac_tax,
  COALESCE(SUM(ps.net_pay),0) as net_sal,
  COALESCE(SUM(ps.department_cnps),0) +
  COALESCE(
  CASE
    WHEN SUM(v.vacation_pay) > #{SystemVariable.value(:cnps_ceiling)}
    THEN ROUND((SUM(v.vacation_pay) * #{SystemVariable.value(:dept_cnps_w_ceil)}) +
        #{SystemVariable.value(:dept_cnps_max_base)})
    ELSE ROUND(SUM(v.vacation_pay) * #{SystemVariable.value(:dept_cnps)})
  END
  ,0) as dept_cnps,
  COALESCE(SUM(ps.department_credit_foncier),0) + COALESCE(ROUND(SUM(v.vacation_pay) * #{SystemVariable.value(:dept_credit_foncier)}),0) as dept_cf,
  COALESCE(SUM(ps.employee_fund),0) as emp_fund
FROM
  employees e
    INNER JOIN people p ON p.id = e.person_id
    LEFT OUTER JOIN payslips ps ON ps.employee_id = e.id AND ps.period_year = :year
    LEFT OUTER JOIN vacations v ON v.employee_id = e.id AND v.period_year = :year AND
                  v.period_year = ps.period_year AND v.period_month = ps.period_month
WHERE
  e.employment_status IN :employment_status AND
  (COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0) > 0)
GROUP BY
  e.id, ps.period_year
ORDER BY
  employee_id ASC, ps.period_year ASC;
    SELECTSTATEMENT
  end

  def report_month
    I18n::l(Date.new(Date.today.year, month().to_i, 1), format: :monthname)
  end

  def formatted_title
    I18n::t(:Employee_yearly_report, scope: [:reports])
  end

end
