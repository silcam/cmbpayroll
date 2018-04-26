class PayBreakdownRfisReport < PayBreakdownAllReport

  def report_name
    "pay_breakdown"
  end

  def segment
    "rfis"
  end

  def formatted_title
    I18n::t(:Pay_breakdown_rfis_report, scope: [:reports])
  end

  def dept
    ids = []

    Department.where("name like ?", "%RFIS%").each do |dept|
      ids << dept.id
    end

    ids
  end

end
