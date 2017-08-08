class MockEmployeeService
  @records

  def initialize
    @records = YAML.load_file('test/json_fixtures/employees.yml')
    set_next_id
  end

  def fetch(id)
    @records.each_value do |record|
      return record.to_json if record['id']==id
    end
    nil
  end

  def all
    @records.values.map{ |record| record.to_json}
  end

  def insert(json)
    new_record = JSON.parse json
    new_record['id'] = assign_next_id
    @records << new_record
    true
  end

  def update(json)
    hash = JSON.parse json
    record = @records.fetch hash['id']
    return insert(json) if record.nil?
    record.merge! hash
  end

  # def find_all(params)
  #   found = @records.select do |key, record|
  #     match = true
  #     params.each do |param, value|
  #       match = ( match and (record[param] == value) )
  #     end
  #     match
  #   end
  #   found
  # end

  def employee(sym)
    @records[sym.to_s]
  end

  private

  def set_next_id
    @next_id = 1
    @records.each_value do |record|
      @next_id = [@next_id, record['id']+1].max
    end
  end

  def assign_next_id
    id = @next_id
    @next_id += 1
    id
  end
end