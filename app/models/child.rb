class Child < ApplicationRecord
  include BelongsToPerson

  belongs_to :parent, class_name: 'Person'

  scope :under_6, -> { joins(:person).where("people.birth_date > (date ? - interval '6 years')", Date.today) }
  scope :under_19, -> { joins(:person).where("people.birth_date > (date ? - interval '19 years')", Date.today) }
end
