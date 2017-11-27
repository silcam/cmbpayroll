class EmployeeAdvanceLoanReport < CMBReport

  def sql
    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.last_name, ', ', p.first_name) as employee_name,
  ps.taxable,
  adv.amount as Advance,
  ps.loan_balance as LoanBalance,
  lb.loan_amount as LoanBalanceFromLoans,
  lpb.payments_amount as LoanPayments,
  lb.loan_amount - lpb.payments_amount as Outst,
  newl.amount as NewLoan
FROM
  employees e
    INNER JOIN people p ON
      p.id = e.person_id
    INNER JOIN payslips ps ON
      ps.employee_id = e.id
    LEFT OUTER JOIN (
      SELECT e.id, sum(l.amount) as loan_amount
      FROM employees e, loans l
      WHERE e.id = l.employee_id
      GROUP BY e.id
    ) lb ON
      e.id = lb.id
    LEFT OUTER JOIN (
      SELECT e.id, sum(lp.amount) as payments_amount
      FROM employees e, loan_payments lp, loans l
      WHERE l.id = lp.loan_id AND e.id = l.employee_id
      GROUP BY e.id
    ) lpb ON
      e.id = lpb.id
    LEFT OUTER JOIN (
      SELECT e.id, c.amount, c.note
      FROM employees e, charges c
      WHERE e.id = c.employee_id AND
        c.date >= :start AND
        c.date <= :finish AND
        c.note like '%allowance%'
    ) adv ON
      e.id = adv.id
    LEFT OUTER JOIN (
      SELECT e.id, l.amount
      FROM employees e, loans l
      WHERE e.id = l.employee_id AND
        l.origination >= :start AND
        l.origination <= :finish
    ) newl ON
      e.id = newl.id
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
      loanbalancefromloans: 'Loan Balance From Loans',
      outst: 'Balance',
      m_c: 'M/C',
      cat_ech: 'Cat / Ech.'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

  # Options selector
  def start
    period = options[:period]
    year, month = period.split('-')

    if (year.nil? || month.nil?)
      year = Period.current.year
      month = Period.current.month
    end

    Date.new(year.to_i, month.to_i, 1)
  end

  # Options selector
  def finish
    period = options[:period]
    year, month = period.split('-')

    if (year.nil? || month.nil?)
      year = Period.current.year
      month = Period.current.month
    end

    Date.new(year.to_i, month.to_i + 1, 1) - 1
  end

  def format_taxable(value)
    cfa_nofcfa(value)
  end

  def format_advance(value)
    cfa_nofcfa(value)
  end

  def format_loanbalancefromloans(value)
    cfa_nofcfa(value)
  end

  def format_loanpayments(value)
    cfa_nofcfa(value)
  end

  def format_outst(value)
    cfa_nofcfa(value)
  end

  def format_newloan(value)
    cfa_nofcfa(value)
  end

end
