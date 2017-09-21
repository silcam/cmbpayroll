class Bonus < ApplicationRecord

  has_and_belongs_to_many :employees

  validates :name, :quantity, :bonus_type, presence: {message: I18n.t(:Not_blank)}
  validates :quantity, numericality: { greater_then: 0.0 }

  enum bonus_type: [ :percentage, :fixed ]

  # TODO: Revisit this.
  # Do we really want to round the bonuses?
  # That could make people think that it's wrong
  # And trim can be replaced by Rails' number_to_human
  def display_quantity
    adj_quantity = trim(round(quantity))
    if (bonus_type == "percentage")
       return "#{adj_quantity}%"
    else
       return "#{adj_quantity} FCFA"
    end
  end

  #
  # Should receive a hash of the form
  #     { "222" => 1 }
  # Where checked bonuses are in the hash
  # and unchecked bonuses are not
  #
  def self.assign_to_employee(employee, bonus_hash)
    if bonus_hash.nil?
      employee.bonuses.clear
    else
      new_bonuses = Bonus.where(id: bonus_hash.keys)
      employee.bonuses = new_bonuses
    end
  end

  private

  def round num
    num.round(2)
  end

  def trim num
    i, f = num.to_i, num.to_f
    i == f ? i : f
  end

end
