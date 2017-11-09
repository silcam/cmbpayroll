class Raise < ApplicationRecord
  belongs_to :employee

  # TODO : How can we avoid reduplicating this code ?
  enum category: [ :one, :two, :three, :four, :five, :six, :seven,
                   :eight, :nine, :ten, :eleven, :twelve, :thirteen ], _prefix: :category
  enum echelon: [ :one, :two, :three, :four, :five, :six, :seven,
                  :eight, :nine, :ten, :eleven, :twelve, :thirteen,
                  :a, :b, :c, :d, :e, :f, :g ], _prefix: :echelon
  enum wage_scale: [ :a, :b, :c, :d, :e ], _prefix: :wage_scale
  enum wage_period: [ :hourly, :monthly ]

  def self.new_for(employee)
    raise = employee.raises.new
    [:category, :echelon, :wage_scale, :wage_period, :wage].each do |param|
      raise.send("#{param}=", employee.send(param))
    end
    raise
  end

  def self.new(params={})
    raise = super(params)
    raise.date = Date.today
    raise
  end
end
