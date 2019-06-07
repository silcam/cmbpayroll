class DipesGovernmentReport < CMBReport

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
  e.cnps as matricule_cnps,
  CASE
    WHEN e.cnps is null THEN ''
    ELSE SUBSTR(replace(e.cnps,'-',''),11,11)
  END as cle,
  DATE_PART('days', DATE_TRUNC('month',concat(ps_year,'-',ps_month,'-01')::date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL) as nb_jour_2,
  COALESCE(ps.gross_pay,0) + COALESCE(v.vacation_pay,0) as salaire_brut_3,
  '' as elements_exception_4,
  COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0) as salaire_taxable_5,
  COALESCE(ps.cnpswage,0) + COALESCE(v.vacation_pay,0) as total_6,
  CASE WHEN (COALESCE(ps.cnpswage,0) + COALESCE(v.vacation_pay,0)) > #{SystemVariable.value(:cnps_ceiling)} THEN #{SystemVariable.value(:cnps_ceiling)} ELSE (COALESCE(ps.cnpswage,0) + COALESCE(v.vacation_pay,0)) END as plafonne_7,
  COALESCE(ps.proportional,0) + COALESCE(v.proportional,0) as retenue_taxe_prop_8,
  0 as retenue_surf_prog_9,
  COALESCE(ps.cac,0) + COALESCE(v.cac,0) as centime_add_com_10,
  COALESCE(ps.communal,0) + COALESCE(v.communal,0) as retenue_taxe_com_11,
  SUBSTRING(e.dipe from 2 for 3) as ligne,
  e.id as employee_id
FROM
  employees e
    INNER JOIN people p ON p.id = e.person_id
    LEFT OUTER JOIN payslips ps ON ps.employee_id = e.id AND ps.period_year = :year AND ps.period_month = :month
    LEFT OUTER JOIN vacations v ON v.employee_id = e.id AND v.period_year = :year AND v.period_month = :month
    JOIN (SELECT id, :month AS ps_month, :year AS ps_year FROM employees) as m ON m.id = e.id
WHERE
  e.employment_status IN :employment_status
ORDER BY
  dipeno,matricule_cnps ASC
    SELECTSTATEMENT
  end

  def dipe_by_page(page)
    SystemVariable.value(:"dipe_page_#{page}")
  end

  def feuille
    feuille_month = start().strftime("%-m").to_i
    if (feuille_month < 7)
      feuille_month += 6
    else
      feuille_month -= 6
    end
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

end
