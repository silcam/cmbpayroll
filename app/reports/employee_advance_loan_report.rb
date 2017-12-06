class EmployeeAdvanceLoanReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ', ', p.first_name) as employee_name,
  ps.taxable,
  COALESCE(adv.amount,0) as Advance,
  ps.loan_balance as LoanBalance,
  COALESCE(paysthismonth.amount,0) as LoanPaymentsThisMonth,
  COALESCE(newloansthismonth.amount,0) as NewLoan,
  COALESCE(ps.loan_balance,0) -
      COALESCE(paysthismonth.amount,0) +
        COALESCE(newloansthismonth.amount,0) as NewLoanB,
  COALESCE(ps.taxable,0) -
      COALESCE(adv.amount,0) -
        COALESCE(paysthismonth.amount,0) as Balance
FROM
  employees e
    INNER JOIN people p ON
      p.id = e.person_id
    INNER JOIN payslips ps ON
      ps.employee_id = e.id
    LEFT OUTER JOIN (
      SELECT e.id, d.amount, d.note
      FROM employees e, payslips ps, deductions d
      WHERE e.id = ps.employee_id AND
        d.payslip_id = ps.id AND
        d.date >= :start AND
        d.date <= :finish AND
        d.note like '%alary%'
    ) adv ON
      e.id = adv.id
    LEFT OUTER JOIN (
      SELECT e.id, l.amount
      FROM employees e, loans l
      WHERE e.id = l.employee_id AND
        l.origination >= :start AND
        l.origination <= :finish
    ) newloansthismonth ON
      e.id = newloansthismonth.id
    LEFT OUTER JOIN (
      SELECT l.employee_id as id, sum(lp.amount) as amount
      FROM loans l, loan_payments lp
      WHERE l.id = lp.loan_id AND
        lp.date >= :start AND
        lp.date <= :finish
      GROUP BY l.employee_id
    ) paysthismonth ON
      e.id = paysthismonth.id
WHERE
  e.employment_status IN :employment_status AND
  ps.period_year = :year AND
  ps.period_month = :month
ORDER BY
  employee_name ASC
    SELECTSTATEMENT
  end

  def formatted_title
    I18n::t(:Employee_advance_loan_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      loanbalance: 'Loan Balance',
      loanpaymentsthismonth: 'Loan Payments This Month',
      newloan: 'New Loans This Month',
      newloanb: 'New Loan Balance',
      m_c: 'M/C',
      cat_ech: 'Cat / Ech.'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  def format_taxable(value)
    cfa_nofcfa(value)
  end

  def format_advance(value)
    cfa_nofcfa(value)
  end

  def format_loanbalance(value)
    cfa_nofcfa(value)
  end

  def format_loanpaymentsthismonth(value)
    cfa_nofcfa(value)
  end

  def format_newloan(value)
    cfa_nofcfa(value)
  end

  def format_newloanb(value)
    cfa_nofcfa(value)
  end

  def format_balance(value)
    cfa_nofcfa(value)
  end

end
