class Employee < JSONBackedModel

  ATTRIBUTES = [:first_name, :last_name]
  ATTRIBUTES.each{ |attr| attr_accessor attr}

  HAS_MANY = [:transactions]
  HAS_MANY.each do |sym|

  end

  validates :first_name, :last_name, presence: {message: I18n.t(:Not_blank)}

  # Used for JSON Serialization
  def attributes
    hash = ATTRIBUTES.map{ |attr| [attr.to_s, nil]}.to_h
    hash.merge(super)
  end

  def full_name
    "#{@first_name} #{@last_name}"
  end
  
  def full_name_rev
    "#{@last_name}, #{@first_name}"
  end

  def get_my(model_s)
    model = model_s.to_s.camelize.singularize.constantize
    model.where(employee_id: @id)
  end
end
