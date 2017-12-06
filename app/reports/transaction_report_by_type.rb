class TransactionReportByType < TransactionReport

  def sql
    TransactionReport::SELECTSTMT + " ORDER BY allitems.type, allitems.note, employee_name ASC"
  end

end
