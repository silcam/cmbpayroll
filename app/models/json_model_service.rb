class JSONModelService

  def initialize
    @employees = [{id: 1, first_name: 'Luke', last_name: 'Skywalker'}]
  end

  def fetch(id)
    @employees.each{ |emp| return emp if emp[:id] == id}
  end

  def all
    @employees
  end

end