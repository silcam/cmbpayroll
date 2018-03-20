class DipesInternalReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ' ', p.first_name) as employee_name,
  e.dipe as dipe,
  SUBSTRING(e.cnps from 0 for 9) as cnps_no,
  e.id as employee_id,
  DATE_PART('days', DATE_TRUNC('month',concat(ps.period_year,'-',ps.period_month,'-01')::date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL) as days,
  ps.gross_pay as salaire_brut,
  ps.taxable as salaire_taxable,
  ps.cnpswage as montant_total,
  ps.proportional as tax_prop,
  0 as tax_progress,
  ps.cac as cac,
  ps.cnps as cnps,
  ps.ccf as credit_foncier,
  ps.crtv as audio_visual,
  ps.total_tax as total_taxes
FROM
  payslips ps
    INNER JOIN employees e ON ps.employee_id = e.id
    INNER JOIN people p ON p.id = e.person_id
    INNER JOIN dipe_codes dc ON e.dipe = dc.line
WHERE
  ps.period_year = :year AND
  ps.period_month = :month
ORDER BY
  dipe ASC
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

  def format_salaire_brut(value)
    cfa_nofcfa(value)
  end

  def format_salaire_taxable(value)
    cfa_nofcfa(value)
  end

  def format_montant_total(value)
    cfa_nofcfa(value)
  end

  def format_tax_prop(value)
    cfa_nofcfa(value)
  end

  def format_cac(value)
    cfa_nofcfa(value)
  end

  def format_cnps(value)
    cfa_nofcfa(value)
  end

  def format_credit_foncier(value)
    cfa_nofcfa(value)
  end

  def format_audio_visual(value)
    cfa_nofcfa(value)
  end

  def format_total_taxes(value)
    cfa_nofcfa(value)
  end

end
