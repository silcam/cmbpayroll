class EmployeeService
  @records

  def initialize
    @records = YAML.load_file('test/json_fixtures/employees.yml')
    id = 1
    @records.each do |key, params|
      params[:id] = id
      id += 1
    end
  end

  def employee(sym)
    Employee.new @records[sym.to_s]
  end
end