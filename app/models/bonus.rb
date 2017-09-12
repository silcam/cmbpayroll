class Bonus < ApplicationRecord

  has_and_belongs_to_many :employees

  validates :name, :quantity, :bonus_type, presence: {message: I18n.t(:Not_blank)}
  validates :quantity, numericality: { greater_then: 0.0 }

  enum bonus_type: [ :percentage, :fixed ]

  #
  # Should receive a hash of the form
  #     { "1111" => 0, "222" => 1 }
  # Where 111 and 222 are bonus ids and
  # 0 and 1 indicate if the bonus should be
  # unassigned or assigned, respectively.
  #
  def self.assign_to_employee(employee, bonus_hash)
    puts "Hash #{bonus_hash.inspect}"

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

end
