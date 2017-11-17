include ApplicationHelper

class Employee < ApplicationRecord
  include BelongsToPerson

  audited allow_mass_assignment: true

  WEEKS_IN_YEAR = 52
  MONTHS_IN_YEAR = 12

  belongs_to :supervisor
  belongs_to :department

  has_many :charges
  has_many :children, {through: :person, source: :children}
  has_many :work_hours
  has_many :work_loans
  has_many :vacations
  has_many :payslips
  has_many :loans
  has_many :raises
  has_many :payslip_corrections, through: :payslips

  has_and_belongs_to_many :bonuses

  validates :title, presence: {message: I18n.t(:Not_blank)}
  validates :hours_day, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 }
  validates :wage, presence: true, if: :echelon_requires_wage?

  scope :active, -> { where.not(employment_status: :inactive) }
  scope :currently_paid, -> {
    statuses = []
    statuses << Employee.employment_statuses['full_time']
    statuses << Employee.employment_statuses['part_time']
    statuses << Employee.employment_statuses['temporary']
    where("employment_status IN (?)", statuses)
  }

  def echelon_requires_wage?
    echelon == "g"
  end

  enum employment_status: [ :full_time, :part_time, :temporary, :leave, :terminated_to_year_end, :inactive]
  enum marital_status: [ :single, :married, :widowed ]
  enum days_week: [ :one, :two, :three, :four, :five, :six, :seven ], _suffix: :day

  enum category: [ :one, :two, :three, :four, :five, :six, :seven,
                    :eight, :nine, :ten, :eleven, :twelve, :thirteen ], _prefix: :category
  enum echelon: [ :one, :two, :three, :four, :five, :six, :seven,
                    :eight, :nine, :ten, :eleven, :twelve, :thirteen,
                    :a, :b, :c, :d, :e, :f, :g ], _prefix: :echelon
  enum wage_scale: [ :a, :b, :c, :d, :e ], _prefix: :wage_scale
  enum wage_period: [ :hourly, :monthly ]

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

  # Time in years between BeginContract and Period.end
  def years_of_service(period)
    # TODO: need a real general purpose date diff by year
    # function since this is likely needed in multiple places.
    return 0 if contract_start.nil?
    return 0 if period.nil?
    ((period.finish - contract_start.to_datetime) / 365).to_i
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
        amical: :amical,
        union: :union_dues_amount
      }
  end

  def total_hours_so_far
    WorkHour.total_hours_so_far self
  end

  def advance_amount
    # TODO verify that this is the correct behavior
    return (wage * SystemVariable.value(:advance_amount)).round
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

  def payslip_for(period)
    payslips.for_period(period).first
  end

  def otrate
    hourly_rate * SystemVariable.value(:ot1)
  end

  def ot2rate
    hourly_rate * SystemVariable.value(:ot2)
  end

  def ot3rate
    hourly_rate * SystemVariable.value(:ot3)
  end

  def children_under_6
    person.children.under_6.count()
  end

  def children_under_19
    person.children.under_19.count()
  end

  def self.search(query)
    joins(:person).where("people.first_name || ' ' || people.last_name ILIKE ?", "%#{query}%")
  end
end
