class PayBreakdownNonrfisReport < PayBreakdownAllReport

  def report_name
    "pay_breakdown"
  end

  def segment
    "non-rfis"
  end

  def formatted_title
    I18n::t(:Pay_breakdown_non_rfis_report, scope: [:reports])
  end

  def location
    locations = []
    locations << Employee.locations["nonrfis"]
    locations << Employee.locations["aviation"]
    locations
  end

end
