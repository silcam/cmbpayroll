class DipesInternalReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  CASE
    WHEN dipe is null OR dipe = '' THEN
      CASE
        WHEN ps.taxable < 25000 THEN 'A01'
        ELSE 'A02'
      END
    ELSE dipe
  END as DIPENo,
  CASE
    WHEN dipe='A01' OR dipe='A02' OR dipe='' OR dipe is null THEN '0'
    ELSE substr(dipe,1,1)
  END as Group,
  substr(e.cnps,0,9) as cnpsno,
  CONCAT(p.first_name, ' ', p.last_name) as employee_name,
  e.id as EmployeeId,
  ps.period_year as year,
  ps.taxable as SalBrut,
  ps.taxable as SalTax,
  ps.cnpswage as montant_total,
  CASE
    WHEN ps.cnpswage > 300000 THEN 300000
    ELSE ps.cnpswage
  END as montant_total_plafonne,
  ps.proportional as tax_prop,
  0 as tax_progress,
  ps.cac as cac,
  ps.cnps as cnps,
  ps.communal as tax_common,
  ps.ccf as credit_foncier,
  ps.crtv as audio_visual,
  ps.total_tax as total_taxes
FROM
  payslips ps
    INNER JOIN employees e ON ps.employee_id = e.id
    INNER JOIN people p ON p.id = e.person_id
WHERE
  ps.period_year = '2018' AND
  ps.period_month = '01'
ORDER BY
  dipeno, cnpsno ASC
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
