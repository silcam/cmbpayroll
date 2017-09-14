class Person < ApplicationRecord

  # A Person could also be a :
  has_one :employee
  has_one :child
  has_one :user
  has_one :supervisor

  has_many :children, foreign_key: :parent_id

  validates :first_name, :last_name, presence: {message: I18n.t(:Not_blank)}

  enum gender: [ :male, :female ]

  default_scope { order(:last_name, :first_name) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name_rev
    "#{last_name}, #{first_name}"
  end

  def self.non_supervisors
    Person.left_outer_joins(:supervisor)
        .left_outer_joins(:child)
        .where('supervisors.id IS NULL')
        .where('children.id IS NULL')
  end

  def self.non_users
    Person.left_outer_joins(:user)
        .left_outer_joins(:child)
        .where('users.id IS NULL')
        .where('children.id IS NULL')
  end
end
