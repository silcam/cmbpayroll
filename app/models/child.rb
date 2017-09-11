class Child < ApplicationRecord
  include BelongsToPerson

  belongs_to :parent, class_name: 'Person'


end
