class DipesInternalReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CASE
    WHEN dipe is null OR dipe = '' THEN
      CASE
        WHEN ps.taxable < #{SystemVariable.value(:a01_cutoff)} THEN 'A01'
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
  DATE_PART('days', DATE_TRUNC('month',concat(ps.period_year,'-',ps.period_month,'-01')::date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL) as days,
  ps.period_year as year,
  ps.taxable + COALESCE(v.vacation_pay,0) as SalBrut,
  ps.taxable + COALESCE(v.vacation_pay,0)  as SalTax,
  ps.cnpswage + COALESCE(v.vacation_pay,0) as montant_total,
  CASE
    WHEN (ps.cnpswage + COALESCE(v.vacation_pay,0)) > #{SystemVariable.value(:cnps_cutoff)} THEN #{SystemVariable.value(:cnps_cutoff)}
    ELSE (ps.cnpswage + COALESCE(v.vacation_pay,0))
  END as montant_total_plafonne,
  ps.proportional + COALESCE(v.proportional,0) as tax_prop,
  0 as tax_progress,
  ps.cac + COALESCE(v.cac,0) as cac,
  ps.cnps + COALESCE(v.cnps,0) as cnps,
  ps.communal + COALESCE(v.communal,0) as tax_common,
  ps.ccf + COALESCE(v.ccf,0) as credit_foncier,
  ps.crtv + COALESCE(v.crtv,0) as audio_visual,
  (ps.proportional + COALESCE(v.proportional,0) +
   0 +
   ps.cac + COALESCE(v.cac,0) +
   ps.cnps + COALESCE(v.cnps,0) +
   ps.communal + COALESCE(v.communal,0) +
   ps.ccf + COALESCE(v.ccf,0) +
   ps.crtv + COALESCE(v.crtv,0)
  ) as total_taxes
FROM
  payslips ps
    INNER JOIN employees e ON ps.employee_id = e.id
    INNER JOIN people p ON p.id = e.person_id
    LEFT OUTER JOIN vacations v ON ps.employee_id = v.employee_id AND ps.period_year = v.period_year AND ps.period_month = v.period_month
WHERE
  e.employment_status IN :employment_status AND
  ps.period_year = :year AND
  ps.period_month = :month
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
