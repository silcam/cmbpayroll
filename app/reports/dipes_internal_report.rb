class DipesInternalReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CASE
    WHEN dipe is null OR dipe = '' THEN
      CASE
        WHEN COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0) < #{SystemVariable.value(:a01_cutoff)} THEN 'A01'
        ELSE 'A02'
      END
    ELSE dipe
  END as DIPENo,
  CASE
    WHEN dipe='A01' OR dipe='A02' OR dipe='' OR dipe is null THEN '0'
    ELSE substr(dipe,1,1)
  END as Group,
  substr(e.cnps,0,9) as cnpsno,
  CONCAT(p.last_name, ' ', p.first_name) as employee_name,
  e.id as EmployeeId,
  DATE_PART('days', DATE_TRUNC('month',concat(ps_year,'-',ps_month,'-01')::date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL) as days,
  ps_year as year,
  COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0) as SalBrut,
  COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0)  as SalTax,
  COALESCE(ps.cnpswage,0) + COALESCE(v.vacation_pay,0) as montant_total,
  CASE
    WHEN (COALESCE(ps.cnpswage,0) + COALESCE(v.vacation_pay,0)) > #{SystemVariable.value(:cnps_cutoff)} THEN #{SystemVariable.value(:cnps_cutoff)}
    ELSE (COALESCE(ps.cnpswage,0) + COALESCE(v.vacation_pay,0))
  END as montant_total_plafonne,
  COALESCE(ps.proportional,0) + COALESCE(v.proportional,0) as tax_prop,
  0 as tax_progress,
  COALESCE(ps.cac,0) + COALESCE(v.cac,0) as cac,
  COALESCE(ps.cnps,0) + COALESCE(v.cnps,0) as cnps,
  COALESCE(ps.communal,0) + COALESCE(v.communal,0) as tax_common,
  COALESCE(ps.ccf,0) + COALESCE(v.ccf,0) as credit_foncier,
  COALESCE(ps.crtv,0) + COALESCE(v.crtv,0) as audio_visual,
  (COALESCE(ps.proportional,0) + COALESCE(v.proportional,0) +
   0 +
   COALESCE(ps.cac,0) + COALESCE(v.cac,0) +
   COALESCE(ps.cnps,0) + COALESCE(v.cnps,0) +
   COALESCE(ps.communal,0) + COALESCE(v.communal,0) +
   COALESCE(ps.ccf,0) + COALESCE(v.ccf,0) +
   COALESCE(ps.crtv,0) + COALESCE(v.crtv,0)
  ) as total_taxes
FROM
  employees e
    INNER JOIN people p ON p.id = e.person_id
    LEFT OUTER JOIN payslips ps ON ps.employee_id = e.id AND ps.period_year = :year AND ps.period_month = :month
    LEFT OUTER JOIN vacations v ON v.employee_id = e.id AND v.period_year = :year AND v.period_month = :month
    JOIN (SELECT id, :month AS ps_month, :year AS ps_year FROM employees) as m ON m.id = e.id
WHERE
  e.employment_status IN :employment_status AND
  (COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0) > 0)
ORDER BY
  dipeno, cnpsno, employee_name ASC
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Dipes_internal_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      cac: 'C.A.C.',
      cnps: 'CNPS'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  def format_days(value)
    value.to_i
  end

end
