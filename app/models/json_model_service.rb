class JSONModelService

  require 'net/http'

  def initialize
    @employees = [{id: 1, first_name: 'Luke', last_name: 'Skywalker'}]
  end

  def fetch(id)
    @employees.each{ |emp| return emp.to_json if emp[:id] == id}
    nil
  end

  def all(options={})
    base_url = "http://localhost:8080/webapi"
    resource_path = "employee"

    uri = URI(base_url << "/" << resource_path)
    Rails.logger.error "RETREIVING ALL from " << uri.to_yaml

    res = Net::HTTP.get_response(uri)

    Rails.logger.error "RECEIVED response: "
    Rails.logger.error "   Status Code: " << res.code
    Rails.logger.error "   Response entity: " << res.body

    if (res.code != '200')
        return false
    end

    Rails.logger.error "Attempting to marshall employees from hash"

    data = JSON.parse(res.body)
    employees_json = []

    Rails.logger.error ">> Data received " << data.to_yaml

    # reform the response to make it like
    # the Mock service.
    data.each { |item|
       Rails.logger.error ">> >> Item: " << item.to_yaml
       employees_json.push(item.to_json)
    }

    Rails.logger.error ">> All Employee Data >> " << employees_json.to_yaml

    return employees_json
  end

  def insert(json)
    base_url = "http://localhost:8080/webapi"
    resource_path = "employee"

    uri = URI(base_url << "/" << resource_path)
    Rails.logger.error "POSTING to " << uri.to_yaml

    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = "application/json"
    req.body = json

    Rails.logger.error "SENDING request body: " << json

    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(req)
    }

    Rails.logger.error "RECEIVED response: "
    Rails.logger.error "   Status Code: " << res.code
    Rails.logger.error "   Response entity: " << res.body

    if (res.code == 200 || res.code == 201)
        return true
    else
        return false
    end

  end
end
