class TransactionReportByName < TransactionReport

  def sql
    TransactionReport::SELECTSTMT + " ORDER BY p.last_name, allitems.type, allitems.note ASC"
  end

end
