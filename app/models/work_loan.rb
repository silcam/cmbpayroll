class WorkLoan < WorkHour
  belongs_to :employee
  belongs_to :department

  def self.for_period(period = Period.current)
    WorkLoan.where(date: period.to_range())
  end

  def self.has_hours_for_period?(period=Period.current)
    self.for_period(period).any?
  end

  def self.total_hours(employee, period=Period.current)
    self.for(employee, period.start, period.finish).sum(:hours)
  end

  def self.total_hours_for_period(period=Period.current)
    self.for_period(period).sum(:hours)
  end

  def self.total_hours_per_department(period=Period.current)
    WorkLoan.unscoped().where(date: period.to_range()).group(:department).sum(:hours)
  end

end
