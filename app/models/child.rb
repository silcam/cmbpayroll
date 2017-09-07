class Child < ApplicationRecord
  include BelongsToPerson

  belongs_to :person
  belongs_to :parent, class_name: 'Person'


end
