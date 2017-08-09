class JSONBackedModel
  include ActiveModel::Model

  def attributes
    @@attributes.map{ |attr| [attr, self.send(attr)]}.to_h
  end

  def attributes=(hash)
    hash.each do |key, value|
      send("#{key}=", value)
    end
  end

  def destroy
    return if new_record?
    service.destroy(@id)
  end

  def initialize(params = {})
    super
    @id ||= nil
  end

  def new_record?
    @id.nil?
  end

  def persisted?
    true
  end

  def save
    return false unless valid?
    if new_record?
      @id = service.insert(to_json)
    else
      service.update(to_json)
    end
  end

  def ==(other)
    not @id.nil? and (@id == other.try(:id))
  end

  def self.all(options = {})
    service.all(options).map{ |json| self.from_json(json)}
  end

  def self.attributes
    @@attributes.clone
  end

  def self.create(params)
    instance = self.new(params)
    instance.save
    instance
  end

  # TODO With Activerecord, find raises an exception if no record is found
  # Might be worth doing the same thing for consistency
  def self.find(id)
    json = service.fetch id.to_i
    return nil if json.nil?
    self.from_json json
  end

  def self.mock_service
    if Rails.env == 'test'
      @@service = mock_service_class.new
    end
  end

  protected # ====================================

  def service
    self.class.service
  end

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

  def self.mock_service_class
    # Override me!
  end

  def self.service
    @@service ||=
        Rails.env == 'test' ?
          mock_service_class.new :
          JSONModelService.new
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
