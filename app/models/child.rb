class Child < ApplicationRecord
  include BelongsToPerson

  belongs_to :parent, class_name: 'Person'

  scope :under_6, -> { joins(:person).where("people.birth_date > (now() - interval '6 years')") }
  scope :under_19, -> { joins(:person).where("people.birth_date > (now() - interval '19 years')") }
end
