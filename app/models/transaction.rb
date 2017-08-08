class Transaction < ApplicationRecord
  extend BelongsToJSONBackedModel

  belongs_to_jbm :employee
end
