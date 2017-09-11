class Charge < ApplicationRecord

  belongs_to :employee

  validates :amount, numericality: {only_integer: true, message: I18n.t(:Must_be_whole_number)}
  validates :date, presence: {messsage: I18n.t(:Not_blank)}

  def self.for_period(period=Period.current)
    where(date: period.to_range)
  end
end
