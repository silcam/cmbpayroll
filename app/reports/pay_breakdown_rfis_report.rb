class PayBreakdownRfisReport < PayBreakdownAllReport

  def formatted_title
    I18n::t(:Pay_breakdown_rfis, scope: [:reports])
  end

  def dept
    ids = []

    Department.where("name like ?", "%RFIS%").each do |dept|
      ids << dept.id
    end

    ids
  end

end
