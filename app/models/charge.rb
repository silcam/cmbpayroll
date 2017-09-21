class Charge < ApplicationRecord

  ADVANCE="Salary Advance"

  belongs_to :employee

  validates :amount, numericality: {only_integer: true, message: I18n.t(:Must_be_whole_number)}
  validates :date, presence: {messsage: I18n.t(:Not_blank)}

  default_scope { order(:date) }

  def self.for_period(period=Period.current)
    where(date: period.to_range)
  end

end
