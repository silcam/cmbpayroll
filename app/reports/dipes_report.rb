class DipesReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  substr(dc.code,1,5) as DIPENo,
  substr(dc.code,6,6) as DIPEKey,
  ps.period_year as year,
  substr(replace(e.cnps,'-',''),1,10) as CNPSNoDashes,
  substr(replace(e.cnps,'-',''),11,11) as CNPSNoDashesKey,
  ROUND(ps.taxable + COALESCE(v.vacation_pay,0),0) as SalBrut,
  ROUND(ps.taxable + COALESCE(v.vacation_pay,0),0) as SalTax,
  ROUND(ps.cnpswage + COALESCE(v.vacation_pay,0),0) as Total,
  ROUND(ps.CNPSWage + COALESCE(v.vacation_pay,0),0) as Plaf,
  ROUND(ps.proportional + COALESCE(v.proportional,0),0) as Reten,
  dc.line_number as LineNo,
  e.id as EmployeeId,
  DATE_PART('days', DATE_TRUNC('month',concat(ps.period_year,'-',ps.period_month,'-01')::date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL)
FROM
  payslips ps
    INNER JOIN employees e ON ps.employee_id = e.id
    INNER JOIN people p ON p.id = e.person_id
    INNER JOIN dipe_codes dc ON e.dipe = dc.line
    LEFT OUTER JOIN vacations v ON ps.employee_id = v.employee_id AND ps.period_year = v.period_year AND ps.period_month = v.period_month
WHERE
  ps.period_year = :year AND
  ps.period_month = :month
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

  def render_txt
    DipesDocument.new(results).generate
  end

end
