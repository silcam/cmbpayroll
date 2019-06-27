class VacationReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ' ', p.first_name) as Employee_Name,
  e.id,
  v.vacation_pay as gross_pay,
  (v.vacation_pay - v.total_tax) as net_pay,
  v.total_tax as total_tax,
  (v.vacation_pay - v.total_tax) as cash_pay,
  CASE
    WHEN v.vacation_pay > #{SystemVariable.value(:cnps_ceiling)}
    THEN ROUND((v.vacation_pay * #{SystemVariable.value(:dept_cnps_w_ceil)}) +
        #{SystemVariable.value(:dept_cnps_max_base)})
    ELSE ROUND(v.vacation_pay * #{SystemVariable.value(:dept_cnps)})
  END as dept_cnps,
  ROUND(v.vacation_pay * #{SystemVariable.value(:dept_credit_foncier)}) as dept_credit_foncier,
  v.vacation_pay +
    CASE
      WHEN v.vacation_pay > #{SystemVariable.value(:cnps_ceiling)}
      THEN ROUND((v.vacation_pay * #{SystemVariable.value(:dept_cnps_w_ceil)}) +
          #{SystemVariable.value(:dept_cnps_max_base)})
      ELSE ROUND(v.vacation_pay * #{SystemVariable.value(:dept_cnps)})
    END +
    ROUND(v.vacation_pay * #{SystemVariable.value(:dept_credit_foncier)}) as total_charge
FROM
  employees e
    JOIN people p ON e.person_id = p.id
    JOIN vacations v ON e.id = v.employee_id AND v.period_year = :year AND v.period_month = :month
WHERE
  e.employment_status IN :employment_status
ORDER BY
  Employee_Name ASC;
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Vacation_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      taxable: 'Gross Wage',
      net_pay: 'Cash Pay'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

end
