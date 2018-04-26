class TransactionReportByType < TransactionReport

  def report_name
    "transaction_audit_by_type"
  end

  def sql
    TransactionReport::SELECTSTMT + " ORDER BY allitems.type, allitems.note, allitems.date, employee_name ASC"
  end

  def formatted_title
    I18n::t(:Transaction_audit_report_by_type, scope: [:reports])
  end

end
