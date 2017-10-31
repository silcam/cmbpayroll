include ApplicationHelper

class Employee < ApplicationRecord
  include BelongsToPerson

  audited allow_mass_assignment: true

  # TODO: some will probably become variables
  ADVANCE_AMOUNT = 0.5 # Half
  INVALID_WAGE = -1

  belongs_to :supervisor
  belongs_to :department

  has_many :charges
  has_many :children, {through: :person, source: :children}
  has_many :work_hours
  has_many :work_loans
  has_many :vacations
  has_many :payslips
  has_many :loans

  has_and_belongs_to_many :bonuses

  validates :title, presence: {message: I18n.t(:Not_blank)}
  validates :hours_day, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 }
  validates :wage, presence: true, if: :echelon_requires_wage?

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
  enum wage_scale: [ :one, :two, :three ], _prefix: :wage_scale
  enum wage_period: [ :hourly, :monthly ]

  def self.list_departments
    depts = Hash.new
    Employee.all.each do |emp|
      depts[emp.department] = 1
    end
    return depts.keys
  end

  def wage
    if (echelon == "g")
      self[:wage]
    else
      find_wage()
    end
  end

  def find_wage
    wage = Wage.find_wage(category, echelon)
    if wage.nil?
      return INVALID_WAGE
    else
      return wage.basewage
    end
  end

  def department_name
    if (department.nil?)
      return ""
    else
      return department.name
    end
  end

  def amical_amount
    if (amical == true)
      return SystemVariable.value(:amical_amount)
    else
      return 0
    end
  end

  def union_dues_amount
    if (uniondues == true)
      return wage() * SystemVariable.value(:union_dues)
    else
      return 0
    end
  end

  def deductable_expenses
      expense_hash = {
        amical: :amical_amount,
        union: :union_dues_amount
      }
  end

  def total_hours_so_far
    WorkHour.total_hours_so_far self
  end

  def advance_amount
    # TODO verify that this is the correct behavior
    return (wage * ADVANCE_AMOUNT).round
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

end
