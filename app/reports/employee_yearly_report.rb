class EmployeeYearlyReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
    SELECT
  e.id as employee_id,
  e.cnps as matricule_cnps,
  CONCAT(MAX(p.first_name), ' ', MAX(p.last_name)) as employee_name,
  ps.period_year as py,
  COALESCE(SUM(ps.taxable),0) + COALESCE(SUM(v.vacation_pay),0) as taxable,
  COALESCE(SUM(ps.ccf),0) + COALESCE(SUM(v.ccf),0) as ccf_tax,
  COALESCE(SUM(ps.cnps),0) + COALESCE(SUM(v.cnps),0) as cnps_tax,
  COALESCE(SUM(ps.proportional),0) + COALESCE(SUM(v.proportional),0) as prop_tax,
  COALESCE(SUM(ps.crtv),0) + COALESCE(SUM(v.crtv),0) as crtv_tax,
  COALESCE(SUM(ps.communal),0) + COALESCE(SUM(v.communal),0) as comm_tax,
  COALESCE(SUM(ps.cac),0) + COALESCE(SUM(v.cac),0) as cac_tax,
  COALESCE(SUM(ps.net_pay),0) as net_sal,
  -- Department CNPS on vacation pay is piecewise (the cnps_ceiling switches
  -- the rate), so it must be computed per MONTH and summed -- not applied to
  -- the whole year's vacation total, which would land in a different ceiling
  -- band and disagree with AnnualPayslipReport (and the real per-period
  -- charge). vac_cnps (joined below) does that per-month sum.
  COALESCE(SUM(ps.department_cnps),0) +
  COALESCE(MAX(vac_cnps.amount),0) as dept_cnps,
  COALESCE(SUM(ps.department_credit_foncier),0) + COALESCE(ROUND(SUM(v.vacation_pay) * #{SystemVariable.value(:dept_credit_foncier)}),0) as dept_cf,
  COALESCE(SUM(ps.employee_fund),0) as emp_fund,
  e.niu as employee_niu
FROM
  employees e
    INNER JOIN people p ON p.id = e.person_id
    LEFT OUTER JOIN payslips ps ON ps.employee_id = e.id AND ps.period_year = :year
    LEFT OUTER JOIN vacations v ON v.employee_id = e.id AND v.period_year = :year AND
                  v.period_year = ps.period_year AND v.period_month = ps.period_month
    -- Per-month vacation department CNPS, summed to the year. Mirrors
    -- AnnualPayslipReport's grain: a vacation contributes only if its month
    -- has a payslip (EXISTS), and the ceiling CASE is applied to each month's
    -- vacation total before summing.
    LEFT OUTER JOIN (
      SELECT vm.employee_id,
        SUM(
          CASE
            WHEN vm.month_pay > #{SystemVariable.value(:cnps_ceiling)}
            THEN ROUND((vm.month_pay * #{SystemVariable.value(:dept_cnps_w_ceil)}) +
                #{SystemVariable.value(:dept_cnps_max_base)})
            ELSE ROUND(vm.month_pay * #{SystemVariable.value(:dept_cnps)})
          END
        ) as amount
      FROM (
        SELECT vv.employee_id, vv.period_month, SUM(vv.vacation_pay) as month_pay
        FROM vacations vv
        WHERE vv.period_year = :year
          AND EXISTS (
            SELECT 1 FROM payslips ps2
            WHERE ps2.employee_id = vv.employee_id
              AND ps2.period_year = vv.period_year
              AND ps2.period_month = vv.period_month
          )
        GROUP BY vv.employee_id, vv.period_month
      ) vm
      GROUP BY vm.employee_id
    ) vac_cnps ON vac_cnps.employee_id = e.id
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
