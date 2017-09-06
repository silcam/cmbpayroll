class Child < ApplicationRecord

  belongs_to :employee

  validates :first_name, :last_name, :birth_date, :is_student, presence: {message: I18n.t(:Not_blank)}
end
