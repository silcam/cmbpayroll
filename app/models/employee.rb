class Employee < ApplicationRecord

  has_many :transactions

  validates :first_name, :last_name, :title, :department, presence: {message: I18n.t(:Not_blank)}

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name_rev
    "#{last_name}, #{first_name}"
  end

end
