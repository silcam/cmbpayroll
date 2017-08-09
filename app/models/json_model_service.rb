class JSONModelService

  def initialize
    @employees = [{id: 1, first_name: 'Luke', last_name: 'Skywalker'}]
  end

  def fetch(id)
    @employees.each{ |emp| return emp.to_json if emp[:id] == id}
    nil
  end

  def all
    @employees
  end

end