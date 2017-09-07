class Person < ApplicationRecord

  # A Person could also be a :
  has_one :employee
  has_one :child
  has_one :user

  has_many :children, inverse_of: :parent

  validates :first_name, :last_name, presence: {message: I18n.t(:Not_blank)}

  enum gender: [ :male, :female ]

  default_scope { order(:last_name, :first_name) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name_rev
    "#{last_name}, #{first_name}"
  end
end
