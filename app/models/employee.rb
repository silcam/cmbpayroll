class Employee < ApplicationRecord

  has_many :transactions

  validates :first_name, :last_name, :title, :department, presence: {message: I18n.t(:Not_blank)}
  validates :hours_day, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 }

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name_rev
    "#{last_name}, #{first_name}"
  end

  enum employment_status: [ :full_time, :part_time ]
  enum gender: [ :male, :female ]
  enum marital_status: [ :single, :married ]
  enum days_week: [ :one, :two, :three, :four, :five, :six, :seven ]
end
