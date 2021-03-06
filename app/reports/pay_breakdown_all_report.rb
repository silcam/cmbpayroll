class PayBreakdownAllReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ', ', p.first_name) as employee_name,
  d.name as department,
  all_pay.pay,
  all_pay.type
FROM
  employees e
    INNER JOIN people p ON e.person_id = p.id
    LEFT OUTER JOIN (
        SELECT employee_id, net_pay as pay, 'REGULAR' as type, period_year, period_month
        FROM payslips
      UNION ALL
        SELECT employee_id, (vacation_pay - total_tax) as pay, 'VACATION' as type, period_year, period_month
        FROM vacations
    ) as all_pay ON e.id = all_pay.employee_id
    LEFT OUTER JOIN departments d ON e.department_id = d.id
WHERE
  e.employment_status IN :employment_status AND
  all_pay.period_year = :year AND
  all_pay.period_month = :month AND
  e.location IN :location
ORDER BY
  type, employee_name ASC
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Pay_breakdown_all_report, scope: [:reports])
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

  def report_name
    "pay_breakdown"
  end

  def segment
    "all"
  end

  def location
    locations = []
    locations << Employee.locations["nonrfis"]
    locations << Employee.locations["rfis"]
    locations << Employee.locations["bro"]
    locations << Employee.locations["gnro"]
    locations << Employee.locations["aviation"]
    locations
  end

  set_callback :execute, :after do

    sums = ["","",0,0,0,0,0,0,0,0,0,0,0]

    @query_results.result.columns << "10000"
    @query_results.result.columns << "5000"
    @query_results.result.columns << "2000"
    @query_results.result.columns << "1000"
    @query_results.result.columns << "500"
    @query_results.result.columns << "100"
    @query_results.result.columns << "50"
    @query_results.result.columns << "25"
    @query_results.result.columns << "10"
    @query_results.result.columns << "5"

    @query_results.result.rows.each do |row|
      bd = pay_breakdown(row[2].to_i)

      sums[2] += row[2].to_i
      row << bd[10000]
      sums[3] += bd[10000]
      row << bd[5000]
      sums[4] += bd[5000]
      row << bd[2000]
      sums[5] += bd[2000]
      row << bd[1000]
      sums[6] += bd[1000]
      row << bd[500]
      sums[7] += bd[500]
      row << bd[100]
      sums[8] += bd[100]
      row << bd[50]
      sums[9] += bd[50]
      row << bd[25]
      sums[10] += bd[25]
      row << bd[10]
      sums[11] += bd[10]
      row << bd[5]
      sums[12] += bd[5]
    end

  end

end
