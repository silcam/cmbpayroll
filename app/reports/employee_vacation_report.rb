class EmployeeVacationReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
select DISTINCT ON (e.id)
  CONCAT(p.first_name, ' ', p.last_name) as employee_name,
  e.id,
  a.vacation_balance,
  a.vacation_pay_earned,
  a.vacation_earned,
  a.last_vacation_end
from
  employees e
    LEFT JOIN people p ON e.person_id = p.id
    LEFT JOIN (
      select
        employee_id,
        period_month,
        period_year,
        last_processed,
        last_vacation_end,
        vacation_balance,
        vacation_pay_earned,
        vacation_earned
      from
        payslips
    ) a ON a.employee_id = e.id
order by
  e.id desc,
  a.period_year desc,
  a.period_month desc;
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Employee_report, scope: [:reports])
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

  #def format_vacation_pay_earned(value)
  #  number_to_currency(value, locale: :cm)
  #end

  def format_vacation_earned(value)
    number_with_precision(value, precision: 2)
  end

end
