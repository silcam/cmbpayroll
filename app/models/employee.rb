class Employee < ApplicationRecord

  has_many :transactions
  has_many :work_hours
  has_many :vacations

  validates :first_name, :last_name, presence: {message: I18n.t(:Not_blank)}

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name_rev
    "#{last_name}, #{first_name}"
  end

end
