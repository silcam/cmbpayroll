module ApplicationHelper

  def current_period_name
    Date.today.strftime("%B")
  end

  def current_period_start
    today = Date.today
    Date.new(today.year, today.month, 1)
  end

  def current_period_end
    current_period_start.next_month - 1
  end
end
