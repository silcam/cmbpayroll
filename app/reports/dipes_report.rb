class DipesReport < CmbReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  substr(dc.code,1,5) as DIPENo,
  substr(dc.code,6,6) as DIPEKey,
  ps_year as year,
  substr(replace(e.cnps,'-',''),1,10) as CNPSNoDashes,
  substr(replace(e.cnps,'-',''),11,11) as CNPSNoDashesKey,
  ROUND(COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0),0) as SalBrut,
  ROUND(COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0),0) as SalTax,
  ROUND(COALESCE(ps.cnpswage,0) + COALESCE(v.vacation_pay,0),0) as Total,
  CASE
    WHEN ROUND(COALESCE(ps.CNPSWage,0) + COALESCE(v.vacation_pay,0),0) > #{SystemVariable.value(:cnps_ceiling)}
    THEN #{SystemVariable.value(:cnps_ceiling)}
    ELSE ROUND(COALESCE(ps.CNPSWage,0) + COALESCE(v.vacation_pay,0),0)
  END as Plaf,
  ROUND(COALESCE(ps.proportional,0) + COALESCE(v.proportional,0),0) as RetenIrpp,
  ROUND(COALESCE(ps.communal,0) + COALESCE(v.communal,0),0) as RetenCommunale,
  dc.line_number as LineNo,
  e.id as EmployeeId,
  DATE_PART('days', DATE_TRUNC('month',concat(ps_year,'-',ps_month,'-01')::date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL),
  ps_month,
  p.first_name as EmployeeFname,
  p.last_name as EmployeeLname
FROM
  employees e
    INNER JOIN people p ON p.id = e.person_id
    LEFT OUTER JOIN payslips ps ON ps.employee_id = e.id AND ps.period_year = :year AND ps.period_month = :month
    LEFT OUTER JOIN dipe_codes dc ON e.dipe = dc.line
    LEFT OUTER JOIN vacations v ON e.id = v.employee_id AND v.period_year = :year AND v.period_month = :month
    JOIN (SELECT id, :month AS ps_month, :year AS ps_year FROM employees) as m ON m.id = e.id
WHERE
  e.employment_status IN :employment_status AND
  ROUND(COALESCE(ps.taxable,0) + COALESCE(v.vacation_pay,0),0) > 0
ORDER BY
  e.id ASC
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Dipes_report, scope: [:reports])
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

  # The DIPE file is a fixed-width government filing and every money field is
  # declared :numeric, which lib/fixy/formatter/numeric.rb enforces as
  # /^\d+$/. Under 5.1 these columns arrived from the adapter as the strings
  # postgres printed -- "581895" -- and passed. Rails 6.1 added
  # "numeric" => PG::TextDecoder::Numeric to add_pg_decoders, so a ROUND(...,0)
  # column now decodes to a BigDecimal whose to_s is "581895.0" (ActiveSupport
  # forces "F" format, so it is the trailing .0 that breaks it, not scientific
  # notation) and DipesRecord raises
  # ArgumentError: Invalid Input (only digits are accepted, not 581895.0).
  #
  # Rounding here rather than in DipesRecord keeps that class a straight
  # positional mapper, and fixes the values for every consumer of the result
  # set rather than only the fixed-width one. The SQL already ROUNDs each of
  # these to zero decimal places, so this is a type change, not a rounding
  # decision -- round rather than to_i so that stays true if the SQL changes.
  %w[salbrut saltax total plaf retenirpp retencommunale].each do |column|
    define_method("format_#{column}") do |value|
      value.nil? ? value : value.round
    end
  end

  def render_txt
    DipesDocument.new(results).generate
  end

end
