class JSONBackedModel
  include ActiveModel::Model

  def initialize(params = {})
    super
    @id ||= nil
  end

  def attributes
    @@attributes.map{ |attr| [attr, self.send(attr)]}.to_h
  end

  def attributes=(hash)
    hash.each do |key, value|
      send("#{key}=", value)
    end
  end

  def save
    return false unless valid?
    if new_record?
      @id = Employee.service.insert(to_json)
    else
      Employee.service.update(to_json)
    end
  end

  def ==(other)
    not @id.nil? and (@id == other.try(:id))
  end

  def new_record?
    @id.nil?
  end

  def persisted?
    true
  end

  def self.attributes
    @@attributes.clone
  end

  def self.all
    service.all.map{ |json| self.from_json(json)}
  end

  # def self.build(params)
  #   self.new params
  # end

  def self.find(id)
    json = service.fetch id
    return nil if json.nil?
    self.from_json json
  end

  def self.mock_service
    if Rails.env == 'test'
      @@service = mock_service_class.new
    end
  end

  protected # ====================================

  def self.define_attributes(attributes)
    @@attributes ||= [:id]
    @@attributes += attributes
    @@attributes.each do |attr|
      attr_accessor attr
    end
  end

  def self.has_many(symbol)
    model = symbol.to_s.camelize.singularize.constantize
    field_name = self.to_s.underscore + '_id'

    define_method symbol do
      model.where(field_name => @id)
    end
  end

  def self.service
    @@service ||=
        Rails.env == 'test' ?
          mock_service_class.new :
          JSONModelService.new
  end

  def self.mock_service_class
    # Override me!
  end

  # Don't know why I can't use this with has_many
  # def self.this_class_id
  #   self.to_s.underscore + '_id'
  # end

  private # =======================================

  def to_json
    attributes.to_json
  end

  def self.from_json(json)
    self.new(JSON.parse(json))
  end

end
