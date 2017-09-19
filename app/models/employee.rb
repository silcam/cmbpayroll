include ApplicationHelper

class Employee < ApplicationRecord
  include BelongsToPerson

  belongs_to :supervisor

  has_many :charges
  has_many :children, {through: :person, source: :children}
  has_many :work_hours
  has_many :vacations
  has_many :payslips

  has_and_belongs_to_many :bonuses

  validates :title, :department, presence: {message: I18n.t(:Not_blank)}
  validates :hours_day, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 }
  validates :wage, presence: true, if: :echelon_requires_wage?

  def echelon_requires_wage?
    echelon == "g"
  end

  enum employment_status: [ :full_time, :part_time ]
  enum marital_status: [ :single, :married ]
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

  def total_hours_so_far
    #TODO is this logic redundant with something somewhere else?
    hours = WorkHour.total_hours_so_far(self)
    hours[:normal] = hours[:normal] - Vacation.missed_hours_so_far(self)
    hours
  end

  def advance_amount
    # TODO verify that this is the correct behavior
    return (wage / 2.0).round
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

end
