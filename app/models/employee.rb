include ApplicationHelper

class Employee < ApplicationRecord
  include BelongsToPerson

  audited allow_mass_assignment: true

  WEEKS_IN_YEAR = 52
  MONTHS_IN_YEAR = 12
  UNION = "union"
  AMICAL = "amical"

  belongs_to :supervisor
  belongs_to :department

  has_many :charges
  has_many :misc_payments
  has_many :children, {through: :person, source: :children}
  has_many :work_hours
  has_many :work_loans
  has_many :vacations
  has_many :payslips
  has_many :loans
  has_many :raises
  has_many :payslip_corrections, through: :payslips

  has_and_belongs_to_many :bonuses

  validates :title, :location, presence: {message: I18n.t(:Not_blank)}
  validates :hours_day, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 }
  validates :wage, presence: true, if: :echelon_requires_wage?
  validate :is_not_own_supervisor

  scope :active, -> { where.not(employment_status: :inactive) }
  scope :nonrfis, -> {
      where.not(location: [
        Employee.statuses[:rfis], Employee.statuses[:bro], Employee.statuses[:gnro],
      ])
  }
  scope :rfis, -> { where("location = ?", Employee.statuses[:rfis]) }
  scope :bro, -> { where("location = ?", Employee.statuses[:bro]) }
  scope :gnro, -> { where("location = ?", Employee.statuses[:gnro]) }
  scope :aviation, -> { where("location = ?", Employee.statuses[:aviation]) }
  scope :currently_paid, -> {
    where("employment_status IN (?)", Employee.active_status_array)
  }

  def echelon_requires_wage?
    echelon == "g"
  end

  enum employment_status: { full_time: 0, part_time: 1, temporary: 2, leave: 3,
                            terminated_to_year_end: 4, inactive:5 }
  enum marital_status: { single: 0, married: 1, widowed: 2 }
  enum days_week: { one: 0, two: 1, three: 2, four: 3, five: 4, six: 5, seven: 6 }, _suffix: :day

  enum category: { one: 0, two: 1, three: 2, four: 3, five: 4, six: 5, seven: 6,
                    eight: 7, nine: 8, ten: 9, eleven: 10, twelve: 11, thirteen: 12 }, _prefix: :category
  enum echelon: { a: 13, b: 14, c: 15, d: 16, e: 17, f: 18, g: 19 }, _prefix: :echelon
  enum wage_scale: { a: 0, b: 1, c: 2, d: 3, e: 4 }, _prefix: :wage_scale
  enum wage_period: { hourly: 0, monthly: 1 }
  enum location: { nonrfis: 0, rfis: 1, bro: 2, gnro: 3, aviation: 4 }

  def gender
    person.gender
  end

  def female?
    person.female?
  end

  def is_currently_paid?
    employment_status == "full_time" ||
        employment_status == "part_time" ||
          employment_status == "temporary"
  end

  def is_on_leave?
    employment_status == "leave"
  end

  def accrues_vacation?
    accrue_vacation == true
  end

  def supervised_by? possible_sup
    my_sup = supervisor
    until my_sup.nil?
      return true if my_sup == possible_sup
      my_sup = my_sup.person.employee.try(:supervisor)
    end
    false
  end

  def is_not_own_supervisor
    if !person.supervisor.nil? and supervised_by? person.supervisor
      errors.add(:base, "Employee cannot be in their own chain of supervisors.")
    end
  end

  def self.list_departments
    depts = Hash.new
    Employee.all.each do |emp|
      depts[emp.department] = 1
    end
    return depts.keys
  end

  def last_raise
    raises.order(date: :desc).first
  end

  def last_normal_raise
    raises.where(is_exceptional: 0).order(date: :desc).first
  end

  def wage
    if (echelon == "g")
      self[:wage]
    else
      find_wage()
    end
  end

  def find_wage
    Wage.find_wage(category, echelon, wage_scale)
  end

  def find_base_wage
    Wage.find_wage(category, "a", wage_scale)
  end

  def paid_monthly?
    wage_period == "monthly"
  end

  def category_value
    Employee.categories[category]
  end

  def echelon_value
    Employee.echelons[echelon]
  end

  def wage_scale_value
    Employee.wage_scales[wage_scale]
  end

  # Time in years between BeginContract and Period.end
  def years_of_service(period=nil)
    # TODO: need a real general purpose date diff by year
    # function since this is likely needed in multiple places.
    return 0 if contract_start.nil?
    period = Period.current if period.nil?

    if (period.finish > contract_start)
      tmp_date = period.finish
      count = 0
      while (tmp_date.prev_year >= contract_start.to_date)
        tmp_date = tmp_date.prev_year
        count += 1
      end

      count
    else
      0
    end
  end

  def workdays_per_month(period)
    workdays = 0
    date = period.start
    days_per_week = days_week_to_i

    while (date <= period.finish)
      # Not sunday, but include days up until days_week
      # e.g. 3 days would count only M,T,W
      if (date.wday > 0 && date.wday <= days_per_week)
          workdays += 1
      end
      date += 1
    end

    workdays
  end

  def daily_rate
    hours_day * hourly_rate
  end

  def hourly_rate
    return 0 if (hours_per_month() == 0)
    (wage / hours_per_month()).round
  end

  # Find out average number of hours per month based on
  # the number of hours expected to work per day
  def hours_per_month
    ((hours_day * days_week_to_i()) * WEEKS_IN_YEAR ).fdiv(MONTHS_IN_YEAR)
  end

  def days_week_to_i
    word_to_int(days_week)
  end

  def department_name
    if (department.nil?)
      return ""
    else
      return department.name
    end
  end

  def department_severance_rate(period=nil)

    years = years_of_service(period)

    if (years > SystemVariable.value(:dept_severance_high_cutoff))
      SystemVariable.value(:dept_severance_high)
    elsif (years > SystemVariable.value(:dept_severance_medium_cutoff))
      SystemVariable.value(:dept_severance_medium)
    elsif (years > SystemVariable.value(:dept_severance_low_cutoff))
      SystemVariable.value(:dept_severance_low)
    else
      0
    end
  end

  # This has `floor()` since it is going into an integer field,
  # and comparing for tests is easier this way.
  def union_dues_amount
    if (uniondues == true)
      return ( find_base_wage() * SystemVariable.value(:union_dues) ).floor
    else
      return 0
    end
  end

  def deductable_expenses
      expense_hash = {
        AMICAL => :amical
      }
  end

  def total_hours_so_far
    WorkHour.total_hours_so_far self
  end

  def has_advance_charge(period)
    if (count_advance_charge(period) > 0)
      return true
    else
      return false
    end
  end

  def count_advance_charge(period)
    count = 0

    charges.each do |charge|
      next if (charge.date < period.start)
      next if (charge.date > period.finish)

      if (charge.note == Charge::ADVANCE)
        count += 1
      end
    end

    return count
  end

  def vacation_summary
    period = LastPostedPeriod.get
    payslip = payslip_for(period)

    summary = {
      period: period,
      balance: payslip.nil? ? 0 : payslip.vacation_balance,
      pay_balance: payslip.nil? ? 0 : payslip.vacation_pay_balance,
    }
  end

  def payslip_for(period)
    payslips.for_period(period).first
  end

  def otrate
    ( hourly_rate * SystemVariable.value(:ot1) ).round
  end

  def ot2rate
    ( hourly_rate * SystemVariable.value(:ot2) ).round
  end

  def ot3rate
    ( hourly_rate * SystemVariable.value(:ot3) ).round
  end

  def children_under_6
    person.children.under_6.count()
  end

  def children_under_19
    person.children.under_19.count()
  end

  def create_location_transfer?
    location != "nonrfis" && location != "rfis"
  end

  def self.active_status_array
    %w(full_time part_time temporary).map { |item| Employee.employment_statuses[item] }
  end

  def self.search(query)
    joins(:person).
        where("people.first_name || ' ' || people.last_name ILIKE ?", "%#{query}%").
        where(employment_status: Employee.active_status_array)
  end
end
