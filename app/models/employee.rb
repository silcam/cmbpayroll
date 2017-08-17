include ApplicationHelper

class Employee < ApplicationRecord

  has_many :transactions
  has_many :work_hours
  has_many :vacations

  validates :first_name, :last_name, presence: {message: I18n.t(:Not_blank)}

  default_scope { order(:last_name, :first_name)}

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name_rev
    "#{last_name}, #{first_name}"
  end

  def total_hours_so_far
    hours = WorkHour.total_hours_so_far(self)
    hours[:normal] = hours[:normal] - Vacation.missed_hours_so_far(self)
    hours
  end

end
