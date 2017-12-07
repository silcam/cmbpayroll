class SalaryChangesReport < CMBReport

  def report_description
    I18n.t(:Salary_changes_report_description, scope: "reports.descriptions")
  end

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ' ', p.first_name) as employee_name,
  e.id as employee_id,
  CONCAT(cur.category, '-', cur.echelon) as new_cat_ech,
  curwages.basewage as new_salary,
  CONCAT(prev.category, '-', prev.echelon) as old_cat_ech,
  prevwages.basewage as previous_salary
FROM
  payslips cur,
  category_lookup curcatlu,
  echelon_lookup curechlu,
  wages curwages,
  payslips prev,
  category_lookup prevcatlu,
  echelon_lookup prevechlu,
  wages prevwages,
  employees e,
  people p
WHERE
  cur.employee_id = e.id AND
  e.person_id = p.id AND
  cur.employee_id = prev.employee_id AND
  cur.echelon = curechlu.emp_val AND
  curechlu.wages_val = curwages.echelonalt AND
  cur.category = curcatlu.emp_val AND
  curcatlu.wages_val = curwages.category AND
  prev.echelon = prevechlu.emp_val AND
  prevechlu.wages_val = prevwages.echelonalt AND
  prev.category = prevcatlu.emp_val AND
  prevcatlu.wages_val = prevwages.category AND
  ( cur.echelon <> prev.echelon OR cur.category <> cur.category) AND
  prev.period_month = :previous_month AND prev.period_year = :previous_year AND
  cur.period_month = :month and cur.period_year = :year;
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Salary_changes_report, scope: [:reports])
  end

  @flavor_text = "Here is some text from the report model"

  def format_header(column_name)
    custom_headers = {
      old_cat_ech: 'Previous Cat/Ech',
      new_cat_ech: 'New Cat/Ech'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  # Options selector
  def previous_year
    period = options[:period]
    year, month = period.split('-')

    begin
      Period.new(year.to_i, month.to_i).previous.year
    rescue InvalidPeriod
      Period.current.previous.year
    end
  end

  # Options selector
  def previous_month
    period = options[:period]
    year, month = period.split('-')

    begin
      Period.new(year.to_i, month.to_i).previous.month
    rescue InvalidPeriod
      Period.current.previous.month
    end
  end

  def format_new_cat_ech(value)
    format_cat_ech(value)
  end

  def format_old_cat_ech(value)
    format_cat_ech(value)
  end

  def format_new_salary(value)
    cfa_nofcfa(value)
  end

  def format_previous_salary(value)
    cfa_nofcfa(value)
  end

end
