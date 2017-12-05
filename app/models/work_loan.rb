include ApplicationHelper

class WorkLoan < ApplicationRecord
  belongs_to :employee
  belongs_to :department

  validates :date, presence: true
  validates :hours, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 24}

  def self.for_period(period = Period.current)
    WorkLoan.where(date: period.to_range())
  end

  def self.has_hours_for_period?(period=Period.current)
    self.for_period(period).any?
  end

  def self.total_hours(employee, period=Period.current)
    where(employee: employee, date: (period.start .. period.finish)).sum(:hours)
  end

  def self.total_hours_for_period(period=Period.current)
    self.for_period(period).sum(:hours)
  end

  def self.total_hours_per_department(period=Period.current)
    WorkLoan.unscoped().joins(:department).where(date: period.to_range()).group(:name).sum(:hours)
  end

  def self.work_loan_hash(employee, period=Period.current)
    dept_work_loans = {}

    employee.work_loans.where(date: period.start..period.finish).each do |wl|
      if (dept_work_loans[wl.department.id])
        dept_work_loans[wl.department.id] += wl.hours
      else
        dept_work_loans[wl.department.id] = wl.hours
      end
    end

    dept_work_loans
  end

end
