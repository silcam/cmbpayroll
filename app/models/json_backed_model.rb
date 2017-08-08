class JSONBackedModel
  include ActiveModel::Model

  define_attributes [:id]

  def initialize(params = {})
    super
    @id ||= nil
  end

  def attributes
    @@attributes.clone
  end

  # Used for reading from JSON (works for reading from a hash too)
  def attributes=(hash)
    hash.each do |key, value|
      send("#{key}=", value)
    end
  end

  def save
    return false unless valid?
    if new_record?
      self.service.insert(self.to_json)
    else
      self.service.update(self.to_json)
    end
  end

  def ==(other)
    not @id.nil? and (@id == other.id)
  end

  def new_record?
    @id.nil?
  end

  def persisted?
    true
  end

  def self.define_attributes(attributes)
    @@attributes = attributes
    @@attributes << :id
    @@attributes.each do |attr|
      attr_accessor attr
    end
  end

  def self.all
    service.all.map{ |json| self.from_json(json)}
  end

  # def self.build(params)
  #   self.new params
  # end

  def self.find(id)
    json = service.fetch id
    self.from_json json
  end

  # TODO more abstraction needed here?
  def self.service
    @@service ||=
        Rails.env == 'test' ?
            MockEmployeeService.new :
            JSONModelService.new
  end

  private

  def self.from_json(json)
    self.new.from_json json
  end
end
