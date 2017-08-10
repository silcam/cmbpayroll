class JSONModelService

  require 'net/http'

  BASE_URL = "http://localhost:8080/webapi"
  RESOURCE_PATH = "employee"

  def initialize
    @employees = [{id: 1, first_name: 'Luke', last_name: 'Skywalker'}]
  end

  def fetch(id)
    res = rest_call_get(id)

    if (res.code != "200")
        return nil
    end

    data = JSON.parse(res.body)
    Rails.logger.debug ">> Data received " << data.to_yaml
    return res.body
  end

  def all(options={})
    res = rest_call_get()

    Rails.logger.debug "Attempting to marshall employees from hash"

    data = JSON.parse(res.body)
    employees_json = []

    Rails.logger.debug ">> Data received " << data.to_yaml

    # reform the response to make it like
    # the Mock service.
    data.each { |item|
       Rails.logger.debug ">> >> Item: " << item.to_yaml
       employees_json.push(item.to_json)
    }

    Rails.logger.debug ">> All Employee Data >> " << employees_json.to_yaml

    return employees_json
  end

  def insert(json)
    res = rest_call_post(json)

    if (res.code == 200 || res.code == 201)
        return true
    else
        return false
    end

  end

  private

    def rest_call_get(id = nil)
      is_post = false
      rest_call(is_post, id)
    end

    def rest_call_post(json)
      is_post = true
      rest_call(is_post, nil, json)
    end

    def rest_call(is_post, id = nil, json = nil)
      uri_string = "#{BASE_URL}/#{RESOURCE_PATH}"
      res = nil

      if (id)
         uri_string += "/#{id}"
      end
      uri = URI(uri_string)

      if (is_post)
        Rails.logger.debug "POST to " << uri.to_yaml
        # if post
        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = "application/json"
        req.body = json
        Rails.logger.debug "SENDING request body: " << json
        res = Net::HTTP.start(uri.hostname, uri.port) {|http|
          http.request(req)
        }
        # end post
      else
        Rails.logger.debug "GET to " << uri.to_yaml
        res = Net::HTTP.get_response(uri)
      end

      Rails.logger.debug "RECEIVED response: "
      Rails.logger.debug "   Status Code: " << res.code
      Rails.logger.debug "   Response entity: " << res.body

      return res
    end
end
