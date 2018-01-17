class TransactionReportByName < TransactionReport

  def sql
    TransactionReport::SELECTSTMT + " ORDER BY p.last_name, allitems.type, allitems.note ASC"
  end

  def formatted_title
    I18n::t(:Transaction_audit_report_by_name, scope: [:reports])
  end

end
