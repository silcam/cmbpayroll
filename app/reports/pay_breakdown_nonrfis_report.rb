class PayBreakdownNonrfisReport < PayBreakdownAllReport

  def formatted_title
    I18n::t(:Pay_breakdown_non_rfis_report, scope: [:reports])
  end

  def dept
    ids = []

    Department.where("name not like ?", "%RFIS%").each do |dept|
      ids << dept.id
    end

    ids
  end

end
