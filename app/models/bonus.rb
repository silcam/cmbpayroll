class Bonus < ApplicationRecord

  has_and_belongs_to_many :employees

  validates :name, :quantity, :bonus_type, presence: {message: I18n.t(:Not_blank)}
  validates :quantity, numericality: { greater_then: 0.0 }

  enum bonus_type: [ :percentage, :fixed ]

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
  #     { "1111" => 0, "222" => 1 }
  # Where 111 and 222 are bonus ids and
  # 0 and 1 indicate if the bonus should be
  # unassigned or assigned, respectively.
  #
  def self.assign_to_employee(employee, bonus_hash)
    logger.debug("Hash #{bonus_hash.inspect}")

    bonus_hash.each do |k,v|
      begin
        bonus = Bonus.find(k)
        if v == "1"
          employee.bonuses << bonus
        else
          employee.bonuses.delete(bonus)
        end
      rescue ActiveRecord::RecordNotUnique
        # ignore
      end
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
