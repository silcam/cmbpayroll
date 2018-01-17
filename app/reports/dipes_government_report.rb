class DipesGovernmentReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  e.cnps as matricule_cnps,
  SUBSTR(replace(e.cnps,'-',''),11,11) as cle,
  DATE_PART('days', DATE_TRUNC('month',concat(ps.period_year,'-',ps.period_month,'-01')::date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL) as nb_jour_2,
  ps.gross_pay as salaire_brut_3,
  '' as elements_exception_4,
  ps.taxable as salaire_taxable_5,
  ps.cnpswage as total_6,
  CASE WHEN ps.cnpswage > 750000 THEN 750000 ELSE ps.cnpswage END as plafonne_7,
  ps.proportional as retenue_taxe_prop_8,
  0 as retenue_surf_prog_9,
  ps.cac as centime_add_com_10,
  ps.communal as retenue_taxe_com_11,
  SUBSTRING(e.dipe from 2 for 3) as ligne,
  e.id as employee_id
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

  def report_month
    I18n::l(Date.new(Date.today.year, month().to_i, 1), format: :monthname)
  end

  def formatted_title
    I18n::t(:Dipes_government_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      cac: 'C.A.C.',
      cnps: 'CNPS',
      employee_id: 'Matricule Intern'
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
