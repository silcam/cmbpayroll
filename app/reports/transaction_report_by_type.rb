class TransactionReportByType < TransactionReport

  def sql
    TransactionReport::SELECTSTMT + " ORDER BY allitems.type, allitems.note, employee_name ASC"
  end

  def formatted_title
    I18n::t(:Transaction_audit_report_by_type, scope: [:reports])
  end

end
