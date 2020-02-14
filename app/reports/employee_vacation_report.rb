class EmployeeVacationReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT DISTINCT ON (e.id)
  CONCAT(p.first_name, ' ', p.last_name) as employee_name,
  e.id,
  ps.vacation_balance,
  ps.vacation_pay_earned,
  ps.vacation_earned,
  ps.last_vacation_end
FROM
  employees e
    LEFT JOIN payslips ps ON ps.employee_id = e.id
    LEFT JOIN people p ON e.person_id = p.id
WHERE
  e.employment_status IN :employment_status AND
  ps.period_month = :month AND
  ps.period_year = :year
ORDER BY
  e.id desc,
  ps.period_year desc,
  ps.period_month desc;
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Employee_vacation_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      vacation_balance: 'Reg. Vacation Balance To Date',
      vacation_pay_earned: 'Reg. Vac. Pay To Date',
      vacation_earned: 'Reg. Vac. Days Current Period'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  def format_vacation_balance(value)
    number_with_precision(value, precision: 2)
  end

  def format_vacation_earned(value)
    number_with_precision(value, precision: 2)
  end

end
