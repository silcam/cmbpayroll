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