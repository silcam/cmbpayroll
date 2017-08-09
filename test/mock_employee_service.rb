class MockEmployeeService
  @records

  def initialize
    @records = YAML.load_file('test/json_fixtures/employees.yml')
    set_next_id
  end

  def fetch(id)
    find(id).try(:to_json)
  end

  def all(options = {})
    records = options[:order].nil? ?
                  @records.values :
                  ordered_records(@records.values,options[:order])
    records.map{ |record| record.to_json}
  end

  def insert(json)
    new_record = JSON.parse json
    new_record['id'] = assign_next_id
    @records[new_record['id']] = new_record
    new_record['id']
  end

  def update(json)
    hash = JSON.parse json
    record = find hash['id']
    return insert(json) if record.nil?
    record.merge! hash
  end

  def destroy(id)
    @records.delete(find_key(id))
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

  def find_key(id)
    @records.each do |key, record|
      return key if record['id']==id
    end
    nil
  end

  def find(id)
    @records[find_key(id)]
  end

  def ordered_records(records, order)
    records.sort do |a, b|
      comparison = 0
      order.each do |rule|
        field = rule.is_a?(Array) ? rule[0] : rule
        asc   = rule.is_a?(Array) ? (rule[1] == :asc) : true
        comparison = a[field.to_s] <=> b[field.to_s]
        comparison = comparison * -1 unless asc
        break unless comparison == 0
      end
      comparison
    end
  end

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