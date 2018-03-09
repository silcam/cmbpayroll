class Raise < ApplicationRecord
  belongs_to :employee

  # TODO : How can we avoid reduplicating this code ?
  enum category: { one: 0, two: 1, three: 2, four: 3, five: 4, six: 5, seven: 6,
                   eight: 7, nine: 8, ten: 9, eleven: 10, twelve: 11, thirteen: 13 }, _prefix: :category
  enum echelon: { a: 13, b: 14, c: 15, d: 16, e: 17, f: 18, g: 19 }, _prefix: :echelon
  enum wage_scale: { a: 0, b: 1, c: 2, d: 3, e: 4 }, _prefix: :wage_scale
  enum wage_period: { hourly: 0, monthly: 1 }

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
