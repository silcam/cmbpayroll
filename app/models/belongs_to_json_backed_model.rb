module BelongsToJSONBackedModel

  def belongs_to_jbm(symbol)
    model = symbol.to_s.camelize.constantize
    field = "#{symbol}_id"

    define_method symbol do
      model.find(send(field))
    end

    define_method :"#{symbol}=" do |owner|
      send(:"#{field}=", owner.id)
    end
  end

  # def employee
  #   Employee.find(employee_id)
  # end
  #
  # def employee=(employee)
  #   employee_id = employee.id
  #   save
  # end

end

class BelongsToJBMValidator < ActiveModel::Validator
  def validate(record)
    unless class_name.find record.send(field_name)
      record.errors[field_name] << 'must_exist'
    end
  end

  protected
  def class_name
    # Override!
  end

  def field_name
    class_name.to_s.underscore + '_id'
  end
end

class BelongsToEmployeeValidator < BelongsToJBMValidator
  def class_name
    Employee
  end
end