class PostReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT DISTINCT ON (e.id)
  CONCAT(p.first_name, ' ', p.last_name) as employee_name,
  e.id,
  ps.loan_balance as Prev_Loan_Balance,
  COALESCE(pmts.amount,0) as Loan_Payments,
  COALESCE(nl.amount,0) as New_Loan,
  (ps.loan_balance - COALESCE(pmts.amount,0) + COALESCE(nl.amount,0)) as Balance,
  ps.vacation_balance - ps.vacation_earned as Vacation_Previous_Days,
  ps.vacation_pay_balance - ps.vacation_pay_earned as Vacation_Previous_Pay,
  ps.vacation_earned as Vacation_New_Days,
  ps.vacation_earned - 1.5 as Supp_Days_Given, -- magic number
  ps.vacation_pay_earned as Vacation_New_Pay,
  ps.vacation_used as Vacation_Used_Days,
  COALESCE(ps.vacation_pay_used,0) as Vacation_Used_Pay,
  ps.vacation_balance as Vacation_Balance_Days,
  ps.vacation_pay_balance as Vacation_Balance_Pay,
  ps.last_vacation_end
FROM
  employees e
    LEFT JOIN people p ON e.person_id = p.id
    LEFT JOIN payslips ps ON ps.employee_id = e.id
    LEFT OUTER JOIN (
      SELECT
        l.employee_id,
        sum(lp.amount) as amount
      FROM
        loans l,
        loan_payments lp
      WHERE
        l.id = lp.loan_id AND
        lp.date BETWEEN :start AND :finish
      GROUP BY
        l.employee_id
    ) pmts ON pmts.employee_id = e.id
    LEFT OUTER JOIN (
      SELECT
        employee_id,
        amount
      FROM
        loans
      WHERE
        origination BETWEEN :start AND :finish
    ) nl ON nl.employee_id = e.id
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
    I18n::t(:Post_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  def format_vacation_balance(value)
    number_with_precision(value, precision: 2)
  end

  def format_vacation_pay_earned(value)
    cfa_nofcfa(value)
  end

  def format_vacation_earned(value)
    number_with_precision(value, precision: 2)
  end

  def format_prev_loan_balance(value)
    cfa_nofcfa(value)
  end

  def format_loan_payments(value)
    cfa_nofcfa(value)
  end

  def format_new_loan(value)
    cfa_nofcfa(value)
  end

  def format_balance(value)
    cfa_nofcfa(value)
  end

  def format_vacation_previous_pay(value)
    cfa_nofcfa(value)
  end

  def format_vacation_new_pay(value)
    cfa_nofcfa(value)
  end

  def format_vacation_used_pay(value)
    cfa_nofcfa(value)
  end

  def format_vacation_balance_pay(value)
    cfa_nofcfa(value)
  end

end
