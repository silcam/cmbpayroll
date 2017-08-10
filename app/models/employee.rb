class Employee < ApplicationRecord
  has_many :transactions

  validates :first_name, :last_name, presence: {message: I18n.t(:Not_blank)}

  default_scope { order(:last_name, :first_name) }

  def full_name
    "#{first_name} #{last_name}"
  end
  
  def full_name_rev
    "#{last_name}, #{first_name}"
  end
end
