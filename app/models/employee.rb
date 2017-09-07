include ApplicationHelper

class Employee < ApplicationRecord
  include BelongsToPerson

  belongs_to :person
  has_many :transactions
  has_many :children, through: :person
  has_many :work_hours
  has_many :vacations

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

  def total_hours_so_far
    #TODO is this logic redundant with something somewhere else?
    hours = WorkHour.total_hours_so_far(self)
    hours[:normal] = hours[:normal] - Vacation.missed_hours_so_far(self)
    hours
  end
end
